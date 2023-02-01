/****************************************
           Excalibur Demo
****************************************/

#include <core.p4>
#include <v1model.p4>

header ethernet_t {
  bit<48> dstAddr;
  bit<48> srcAddr;
  bit<16> etherType;
}
header ipv4_t {
  bit<4>  version;
  bit<4>  ihl;
  bit<8>  diffserv;
  bit<16> totalLen;
  bit<16> identification;
  bit<3>  flags;
  bit<13> fragOffset;
  bit<8>  ttl;
  bit<8>  protocol;
  bit<16> hdrChecksum;
  bit<32> srcAddr;
  bit<32> dstAddr;
}
struct headers {
  ethernet_t ethernet;
  ipv4_t     ipv4;
}
parser ParserImpl(packet_in packet, out headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
  state parse_ethernet {
      packet.extract(hdr.ethernet);
      transition select(hdr.ethernet.etherType) {
          16w0x800: parse_ipv4;
          default: accept;
      }
  }
  state parse_ipv4 {
      packet.extract(hdr.ipv4);
      transition accept;
  }
  state start {
      transition parse_ethernet;
  }
}
struct metadata_t {
  bit<1>  is_loop;
  bit<8>  color;
  bit<48> told;
  bit<48> tdif;
  bit<16> testing_status;
  bit<8>  testing_number_count;
  bit<64> testing_register_value;
}
struct metadata {
  metadata_t md;
}

control ingress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
  meter<bit<32>>(32w1, MeterType.packets) rate_limiter;
  register<bit<8>, bit<32>>(32w1) test_number_count_register;
  register<bit<64>, bit<32>>(32w1) testing_controller_register;
  action calculate_tdif() {
    testing_controller_register.read(meta.md.testing_register_value, (bit<32>)32w0);
    meta.md.testing_status = (bit<16>)((meta.md.testing_register_value & 64w0xffff000000000000) >> 48);
    meta.md.told = (bit<48>)(meta.md.testing_register_value & 64w0xffffffffffff);
    meta.md.tdif = standard_metadata.ingress_global_timestamp - meta.md.told;
  }
  action duration_control() {
    meta.md.testing_register_value = (bit<64>)standard_metadata.ingress_global_timestamp;
    testing_controller_register.write((bit<32>)32w0, (bit<64>)meta.md.testing_register_value);
  }
  action interval_control() {
    meta.md.testing_register_value = (bit<64>)standard_metadata.ingress_global_timestamp;
    testing_controller_register.write((bit<32>)32w0, (bit<64>)(meta.md.testing_register_value | 64w0x1000000000000));
  }
  action termination_control() {
    test_number_count_register.read(meta.md.testing_number_count, (bit<32>)32w0);
    meta.md.testing_number_count = meta.md.testing_number_count + 8w1;
    test_number_count_register.write((bit<32>)32w0, (bit<8>)meta.md.testing_number_count);
  }
  action rate_control() {
    rate_limiter.execute_meter((bit<32>)32w0, meta.md.color);
  }
  action do_recirulation() {
    resubmit({ meta.md.is_loop });
  }
  action drop_packet() {
    mark_to_drop(standard_metadata);
  }
  action set_loop_and_recirculate() {
    meta.md.is_loop = 1w1;
    resubmit({ meta.md.is_loop });
  }
  action send_to_loopback_port(PortId_t port) {
    standard_metadata.egress_spec = port;
  }
  table calculate_tdif_MAT {
   actions = {
      calculate_tdif;
    }
    const default_action = calculate_tdif();
  }
  table duration_control_MAT {
    actions = {
      duration_control;
    }
    const default_action = duration_control();
  }
  table interval_control_MAT {
    actions = {
      interval_control;
    }
    const default_action = interval_control();
  }
  table meter_MAT {
    actions = {
      rate_control;
    }
    const default_action = rate_control();
  }
  table recirculation_MAT {
    actions = {
      set_loop_and_recirculate;
    }
    const default_action = set_loop_and_recirculate();
  }
  table termination_control_MAT {
    actions = {
      termination_control;
    }
    const default_action = termination_control();
  }
  table send_to_loopback_port_MAT {
    key = {
      standard_metadata.ingress_port : exact; 
    }
    actions = {
      send_to_loopback_port;
    }
    const default_action = send_to_loopback_port();
  }
  /* Note: we define a replica of send_to_loopback_port_MAT
     to avoid the compilation error of multiple table invocation */
  table send_to_loopback_port_MAT_replica {
    key = {
      standard_metadata.ingress_port : exact; 
    }
    actions = {
      send_to_loopback_port;
    }
    const default_action = send_to_loopback_port();
  }
  table drop_packet_MAT {
    actions = {
      drop_packet;
    }
    const default_action = drop_packet();
  }

  apply {
    if (meta.md.is_loop == 1w0) {
      recirculation_MAT.apply();
    } else {
      calculate_tdif_MAT.apply();
      if (meta.md.testing_status == 16w1) {
        if (meta.md.tdif >= 48w1000000) {
          duration_control_MAT.apply();
          send_to_loopback_port_MAT.apply();
        }
      } else {
        if (meta.md.testing_status == 16w0) {
          if (meta.md.tdif >= 48w1000000) {
            termination_control_MAT.apply();
            if (meta.md.testing_number_count >= 8w5) {
              drop_packet_MAT.apply();
            } else {
              interval_control_MAT.apply();
              send_to_loopback_port_MAT.apply();
            }
          }
        }
      }
      meter_MAT.apply();
      if (meta.md.color == 8w2) {
        send_to_loopback_port_MAT_replica.apply();
      }
    }
  }
}


control egress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
  apply { }
}
control verifyChecksum(inout headers hdr, inout metadata meta) {
  apply { }
}
control computeChecksum(inout headers hdr, inout metadata meta) {
  apply { }
}
control DeparserImpl(packet_out packet, in headers hdr) {
  apply {
      packet.emit(hdr.ethernet);
      packet.emit(hdr.ipv4);
  }
}
V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(), DeparserImpl()) main;


