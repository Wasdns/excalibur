## Excalibur: A Scalable and Low-Cost Testing Framework for Evaluating DDoS Defense Solutions

To date, security researchers evaluate their solutions of mitigating distributed denial-of-service (DDoS) attacks via kernel-based or kernel-bypassing testing tools. However, kernelbased tools exhibit poor scalability in attack traffic generation while kernel-bypassing tools incur unacceptable monetary cost. We propose Excalibur, a scalable and low-cost testing framework for evaluating DDoS defense solutions. The key idea is to leverage the emerging programmable switch to empower testing tasks with Tbps-level scalability and low cost. Specifically, Excalibur offers intent-based primitives to enable academic researchers to customize testing tasks on demand. Moreover, in view of switch resource limitations, Excalibur coordinates both a server and a programmable switch to jointly perform testing tasks. It realizes flexible attack traffic generation, which requires a large number of resources, in the server while using the switch to increase the sending rate of attack traffic to Tbps-level. We have implemented Excalibur on a 64×100 Gbps Tofino switch. Our experiments on a 64×100 Gbps Tofino switch show that Excalibur achieves orders-of-magnitude higher scalability and lower cost than existing tools.

This repo contains the source code of Excalibur that targets a software-based programmable switch, BMv2. 

### Tutorial

First, install [BMv2](https://github.com/p4lang/behavioral-model) and [P4C](https://github.com/p4lang/p4c).

Second, according to the path of BMv2 in the first step, modify the paths in env.sh.

Third, compile the server agent:

```
cd dpdk/
make
cd ..
```

Fourth, launch BMv2:

```
./run_bmv2.sh
```

Fifth, open a xterm terminal in the mininet terminal:

```
mininet> xterm h1
```

Sixth, in the xterm of h1, send traffic to BMv2 by running the server agent.
