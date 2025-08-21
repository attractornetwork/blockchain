# Attractor Blockchain repository

This project provides a modular, reproducible environment for developing, testing, and running [Polygon CDK](https://docs.agglayer.dev/cdk/) devnets using [Kurtosis](https://kurtosis.com/), specifically customized for Attractor Network.

Specifically, this repo will deploy:

1. A local L2 chain, with customizable components such as sequencer, sequence sender, aggregator, rpc, prover, dac, etc. It will first deploy the [Polygon zkEVM smart contracts](https://github.com/0xPolygonHermez/zkevm-contracts) on the L1 chain before deploying the different components.
2. The [zkEVM bridge](https://github.com/0xPolygonHermez/zkevm-bridge-service) infrastructure to facilitate asset bridging between the L1 and L2 chains, and vice-versa.
3. The [Agglayer](https://github.com/agglayer/agglayer-go), an in-development interoperability protocol, that allows for trustless cross-chain token transfers and message-passing, as well as more complex operations between L2 chains, secured by zk proofs.
4. Additional services: bridge, transaction explorer, grafana + prometheus dashboard.

Optional features:

- Run transaction and bridge spammers to simulate network load.
- Deploy monitoring solutions such as [Prometheus](https://prometheus.io/), [Grafana](https://grafana.com/), [Panoptichain](https://github.com/0xPolygon/panoptichain) and [Blockscout](https://www.blockscout.com/) to observe the network.

> 🚨 This package is for development and testing only — **not for production use!**

## Sections

### [Getting Started](./docs/docs/introduction/getting-started.md)

Install Kurtosis and set up your first devnet.

### [Configuration](./docs/docs/configuration/overview.md)

Learn how to configure your devnet deployment.

### [Version Matrix](./docs/docs/version-matrix.md)

A list of all test environments with their configurations and component versions.

### [Contributing](./docs/docs/contributing.md)

Help us improve the package.

### Appendix

References, troubleshooting, and more.

- [FAQ](./docs/docs/appendix/faq.md)

## Contact

- For technical issues, join our [Telegram](https://t.me/AttractorOfficial).
- For documentation issues, raise an issue on the published live doc at [web-page](https://attra.me).

## License

Copyright (c) 2024 PT Services DMCC

Licensed under either:

- Apache License, Version 2.0, ([LICENSE-APACHE](./LICENSE-APACHE) or <http://www.apache.org/licenses/LICENSE-2.0>), or
- MIT license ([LICENSE-MIT](./LICENSE-MIT) or <http://opensource.org/licenses/MIT>)

as your option.

The SPDX license identifier for this project is `MIT` OR `Apache-2.0`.

## Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.
