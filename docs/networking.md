# networking

This document aims to capture the networking requirements of the cluster.

### ingress

| | | | | | |
| - | - | - | - | - | - |
|         | cfssl | etcd | masters | workers | external |
| cfssl   | * | 8888/TCP | 8888/TCP, 8889/TCP | 8888/TCP | - |
| etcd    | - | * | 2379/TCP | 2381/TCP, 9100/TCP | - |
| masters | - | - | * | * | 443/TCP |
| workers | - | - | * | * | ? |


For accessing kubernetes ingresses, you will have to open the appropriate ports, which depend on your setup.

It's also recommended to open port 22 on all nodes for SSH access.
