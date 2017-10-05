# networking

This document aims to capture the networking requirements of the cluster.

### ingress

| | | | | | |
| - | - | - | - | - | - |
|         | cfssl | etcd | masters | workers | external |
| cfssl   | * | 8888/TCP<sup>1</sup> | 8888/TCP, 8889/TCP<sup>2</sup> | 8888/TCP | - |
| etcd    | - | * | 2379/TCP<sup>3</sup> | 2381/TCP<sup>4</sup>, 9100/TCP<sup>5</sup> | - |
| masters | - | - | * | * | 443/TCP<sup>6</sup> |
| workers | - | - | * | * | ? |


1. `cfssl` API
1. HTTP server which servers the kubernetes signing key
1. `etcd` client port
1. unauthenticated `etcd` metrics
1. prometheus `node_exporter` metrics
1. kubernetes `apiserver`

For accessing kubernetes ingresses, you will have to open the appropriate ports, which depend on your setup.

It's also recommended to open port 22 on all nodes for SSH access.
