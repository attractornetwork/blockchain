# Attractor Blockchain repository

Specifically, this repo will deploy:

1. A local L2 chain, with customizable components such as sequencer, sequence sender, aggregator, rpc, prover, dac, etc. It will first deploy the [Polygon zkEVM smart contracts](https://github.com/0xPolygonHermez/zkevm-contracts) on the L1 chain before deploying the different components.
2. The [zkEVM bridge](https://github.com/0xPolygonHermez/zkevm-bridge-service) infrastructure to facilitate asset bridging between the L1 and L2 chains, and vice-versa.
3. The [Agglayer](https://github.com/agglayer/agglayer-go), an in-development interoperability protocol, that allows for trustless cross-chain token transfers and message-passing, as well as more complex operations between L2 chains, secured by zk proofs.
4. Additional services: bridge, transaction explorer, grafana + prometheus dashboard.

## Contact

- For technical issues, join our [Telegram](https://t.me/AttractorOfficial).
- For documentation issues, raise an issue on the published live doc at [web-page](https://attra.me).
