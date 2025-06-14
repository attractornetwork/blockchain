constants = import_module("./src/package_io/constants.star")
dict = import_module("./src/package_io/dict.star")

# The deployment process is divided into various stages.
# You can deploy the whole stack and then only deploy a subset of the components to perform an
# an upgrade or to test a new version of a component.
DEFAULT_DEPLOYMENT_STAGES = {
    # Deploy a local L1 chain using the ethereum-package.
    # Set to false to use an external L1 like Sepolia.
    # Note that it will require a few additional parameters.
    "deploy_l1": True,
    # Deploy zkevm contracts on L1 (as well as fund accounts).
    # Set to false to use pre-deployed zkevm contracts.
    # Note that it will require a few additional parameters.
    "deploy_zkevm_contracts_on_l1": True,
    # Deploy databases.
    "deploy_databases": True,
    # Deploy CDK central/trusted environment.
    "deploy_cdk_central_environment": True,
    # Deploy CDK bridge infrastructure.
    "deploy_cdk_bridge_infra": True,
    # Deploy CDK bridge UI.
    "deploy_cdk_bridge_ui": False,
    # Deploy the agglayer.
    "deploy_agglayer": True,
    # Deploy cdk-erigon node.
    # TODO: Remove this parameter to incorporate cdk-erigon inside the central environment.
    "deploy_cdk_erigon_node": True,
    # Deploy Optimism rollup.
    # Note the default behavior will only deploy the OP Stack without CDK Erigon stack.
    # Setting to True will deploy the Aggkit components and Sovereign contracts as well.
    # Requires consensus_contract_type to be "pessimistic".
    "deploy_optimism_rollup": False,
    # After deploying OP Stack, upgrade it to OP Succinct.
    # Even mock-verifier deployments require an actual SPN network key.
    "deploy_op_succinct": False,
    # Deploy contracts on L2 (as well as fund accounts).
    "deploy_l2_contracts": False,
}

DEFAULT_IMAGES = {
    # "aggkit_image": "goranethernal/aggkit:v0.0.2-beta8",  # https://github.com/agglayer/aggkit/pkgs/container/aggkit
    # "aggkit_image": "jestpol/aggkit:v0.0.2-beta9",  # https://github.com/agglayer/aggkit/pkgs/container/aggkit
    # "aggkit_image": "arnaubennassar/aggkit:477acb6",  # https://github.com/agglayer/aggkit/pkgs/container/aggkit
    "aggkit_image": "goranethernal/aggkit:v0.0.2-beta15",  # https://github.com/agglayer/aggkit/pkgs/container/aggkit
    "agglayer_image": "ghcr.io/agglayer/agglayer:0.3.0-rc.16",  # https://github.com/agglayer/agglayer/pkgs/container/agglayer
    "aggkit_prover_image": "ghcr.io/agglayer/aggkit-prover:0.1.0-rc.20",  # https://github.com/agglayer/provers/pkgs/container/aggkit-prover
    "cdk_erigon_node_image": "hermeznetwork/cdk-erigon:v2.61.19",  # https://hub.docker.com/r/hermeznetwork/cdk-erigon/tags
    "cdk_node_image": "ghcr.io/0xpolygon/cdk:0.5.4-rc1",  # https://github.com/0xpolygon/cdk/pkgs/container/cdk
    "cdk_validium_node_image": "ghcr.io/0xpolygon/cdk-validium-node:0.6.4-cdk.10",  # https://github.com/0xPolygon/cdk-validium-node/pkgs/container/cdk-validium-node/
    "zkevm_bridge_proxy_image": "haproxy:3.1-bookworm",  # https://hub.docker.com/_/haproxy/tags
    "zkevm_bridge_service_image": "hermeznetwork/zkevm-bridge-service:v0.6.0-RC16",  # https://hub.docker.com/r/hermeznetwork/zkevm-bridge-service/tags
    "zkevm_bridge_ui_image": "leovct/zkevm-bridge-ui:multi-network",  # https://hub.docker.com/r/leovct/zkevm-bridge-ui/tags
    # TODO: Update the image to the official version.
    "zkevm_contracts_image": "jhkimqd/zkevm-contracts:v10.0.0-rc.6-fork.12",  # https://hub.docker.com/repository/docker/leovct/zkevm-contracts/tags
    "zkevm_da_image": "ghcr.io/0xpolygon/cdk-data-availability:0.0.13",  # https://github.com/0xpolygon/cdk-data-availability/pkgs/container/cdk-data-availability
    "zkevm_node_image": "hermeznetwork/zkevm-node:v0.7.3",  # https://hub.docker.com/r/hermeznetwork/zkevm-node/tags
    "zkevm_pool_manager_image": "hermeznetwork/zkevm-pool-manager:v0.1.2",  # https://hub.docker.com/r/hermeznetwork/zkevm-pool-manager/tags
    "zkevm_prover_image": "hermeznetwork/zkevm-prover:v8.0.0-RC16-fork.12",  # https://hub.docker.com/r/hermeznetwork/zkevm-prover/tags
    "zkevm_sequence_sender_image": "hermeznetwork/zkevm-sequence-sender:v0.2.4",  # https://hub.docker.com/r/hermeznetwork/zkevm-sequence-sender/tags
    "anvil_image": "ghcr.io/foundry-rs/foundry:v1.0.0",  # https://github.com/foundry-rs/foundry/pkgs/container/foundry/versions?filters%5Bversion_type%5D=tagged
    "mitm_image": "mitmproxy/mitmproxy:11.1.3",  # https://hub.docker.com/r/mitmproxy/mitmproxy/tags
    "op_succinct_contract_deployer_image": "atanmarko/op-succinct-contract-deployer:v1.2.11-agglayer",  # https://hub.docker.com/r/jhkimqd/op-succinct-contract-deployer
    "op_succinct_server_image": "ghcr.io/agglayer/op-succinct/succinct-proposer:v1.2.12-agglayer",  # https://github.com/agglayer/op-succinct/pkgs/container/op-succinct%2Fsuccinct-proposer
    "op_succinct_proposer_image": "ghcr.io/agglayer/op-succinct/op-proposer:v1.2.12-agglayer",  # https://github.com/agglayer/op-succinct/pkgs/container/op-succinct%2Fop-proposer
}

DEFAULT_PORTS = {
    # agglayer-node
    "agglayer_grpc_port": 4443,
    "agglayer_readrpc_port": 4444,
    "agglayer_admin_port": 4446,
    "agglayer_metrics_port": 9092,
    # agglayer-prover
    "agglayer_prover_port": 4445,
    "agglayer_prover_metrics_port": 9093,
    # aggkit-prover
    "aggkit_prover_grpc_port": 4446,
    "aggkit_prover_metrics_port": 9093,
    "prometheus_port": 9091,
    "zkevm_aggregator_port": 50081,
    "zkevm_bridge_grpc_port": 9090,
    "zkevm_bridge_rpc_port": 8080,
    "zkevm_bridge_ui_port": 80,
    "zkevm_bridge_metrics_port": 8090,
    "zkevm_dac_port": 8484,
    "zkevm_data_streamer_port": 6900,
    "zkevm_executor_port": 50071,
    "zkevm_hash_db_port": 50061,
    "zkevm_pool_manager_port": 8545,
    "zkevm_pprof_port": 6060,
    "zkevm_rpc_http_port": 8123,
    "zkevm_rpc_ws_port": 8133,
    "zkevm_cdk_node_port": 5576,
    "blockscout_frontend_port": 3000,
    "anvil_port": 8545,
    "mitm_port": 8234,
    "op_succinct_server_port": 3000,
    "op_succinct_proposer_metrics_port": 7300,
    "op_succinct_proposer_rpc_port": 8545,
    "op_proposer_port": 8560,
}

DEFAULT_STATIC_PORTS = {
    "static_ports": {
        ## L1 static ports (50000-50999).
        "l1_el_start_port": 50000,
        "l1_cl_start_port": 50010,
        "l1_vc_start_port": 50020,
        "l1_additional_services_start_port": 50100,
        ## L2 static ports (51000-51999).
        # Agglayer (51000-51099).
        "agglayer_start_port": 51000,
        "agglayer_prover_start_port": 51010,
        # CDK node (51100-51199).
        "cdk_node_start_port": 51100,
        # Bridge services (51200-51299).
        "zkevm_bridge_service_start_port": 51200,
        "zkevm_bridge_ui_start_port": 51210,
        "reverse_proxy_start_port": 51220,
        # Databases (51300-51399).
        "database_start_port": 51300,
        "pless_database_start_port": 51310,
        # Pool manager (51400-51499).
        "zkevm_pool_manager_start_port": 51400,
        # DAC (51500-51599).
        "zkevm_dac_start_port": 51500,
        # ZkEVM Provers (51600-51699).
        "zkevm_prover_start_port": 51600,
        "zkevm_executor_start_port": 51610,
        "zkevm_stateless_executor_start_port": 51620,
        # CDK erigon (51700-51799).
        "cdk_erigon_sequencer_start_port": 51700,
        "cdk_erigon_rpc_start_port": 51710,
        # L2 additional services (52000-52999).
        "arpeggio_start_port": 52000,
        "blutgang_start_port": 52010,
        "erpc_start_port": 52020,
        "panoptichain_start_port": 52030,
    }
}

# Addresses and private keys of the different components.
# They have been generated using the following command:
# polycli wallet inspect --mnemonic 'lab code glass agree maid neutral vessel horror deny frequent favorite soft gate galaxy proof vintage once figure diary virtual scissors marble shrug drop' --addresses 12 | tee keys.txt | jq -r '.Addresses[] | [.ETHAddress, .HexPrivateKey] | @tsv' | awk 'BEGIN{split("sequencer,aggregator,claimtxmanager,timelock,admin,loadtest,agglayer,dac,proofsigner,l1testing,aggoracle,sovereignadmin",roles,",")} {print "# " roles[NR] "\n\"zkevm_l2_" roles[NR] "_address\": \"" $1 "\","; print "\"zkevm_l2_" roles[NR] "_private_key\": \"0x" $2 "\",\n"}'
DEFAULT_ACCOUNTS = {
    "zkevm_l2_sequencer_address": "0x8A468c758C1a9A0dB1D4E58F62f052DE8FB03B7e",
    "zkevm_l2_sequencer_private_key": "0x5122c3cea6263c6029f7468a513a42cf749a006b8bab573dcc710baa89141481",

    "zkevm_l2_aggregator_address": "0xB144b2aD5a92B30E95d06c090B1284362ce10A22",
    "zkevm_l2_aggregator_private_key": "0x396f98c8d617723ea4d7e14acac589197f51444e7a51772f75b6be4a6e46a43b",

    "zkevm_l2_claimtxmanager_address": "0xBC6bcc1600f5aC8a2843be3057B4098A9F9e4e01",
    "zkevm_l2_claimtxmanager_private_key": "0xa4ee8f4a9a7b13e78876d0fd324cf009a6668ded3662c01a82faea5bd90dfe27",

    "zkevm_l2_timelock_address": "0x488FFD91b6100d5E221C91de0cD53dCFc1EB9529",
    "zkevm_l2_timelock_private_key": "0xa1f6036a8d8b020d7378bed92f335408ebd73dc782322505b1dd098cf1f5d291",

    "zkevm_l2_admin_address": "0x58323B1796c2345D6e39Fb18AA0a0363d117B99B",
    "zkevm_l2_admin_private_key": "0x2d2a9c4e2b73000b5cb182d52acabca202774289487b0ce068fb36017ec013ea",

    "zkevm_l2_loadtest_address": "0xC4FED68A2AA408D7948CF5070b09fCA7585bAc8c",
    "zkevm_l2_loadtest_private_key": "0x6beeed13c632e12b5b6728537efab68afb200c8e3a66a061802d30249e879dda",

    "zkevm_l2_agglayer_address": "0x60f59aE67386D320f0a169E174D53dD80dE90D6e",
    "zkevm_l2_agglayer_private_key": "0x937ef86cd4c42dc6ae6ee35d29d0e3cd149d792f1f0a03b8cd8213cf7fc73348",

    "zkevm_l2_dac_address": "0x003A7EA8f51dd4AF472D6B1a63CE91379C9DDed5",
    "zkevm_l2_dac_private_key": "0x183a50767b9220edd1abb37e359cc12ccbd82f7b01c85becd58fa108af4d1e87",

    "zkevm_l2_proofsigner_address": "0x5d064eEEc2958Cda9336E206c75c1450a345c866",
    "zkevm_l2_proofsigner_private_key": "0x5a818a8c6037d7d83b7ed8b77a4603a4ee5e2d5e30e68b70899931d8fecb1181",

    "zkevm_l2_l1testing_address": "0xdd663E6e771df26d2d2352e6cB7B711BBb4f1225",
    "zkevm_l2_l1testing_private_key": "0x8c37815d3dfb6bec172227d09d981e0cd7e9a3ff1ee20e0864dfa360ebbe2ee1",

    "zkevm_l2_aggoracle_address": "0x95d7109795a8F2f473F264D4ea67127fa960b014",
    "zkevm_l2_aggoracle_private_key": "0xb08f0d7cbb53b32a6d46bfab11c31b549ec47b24af11cad68207e7aee83f5e5a",

    "zkevm_l2_sovereignadmin_address": "0x605a6Dbc3D3B83eC3235083BbFDaf1f4d0Fc1a81",
    "zkevm_l2_sovereignadmin_private_key": "0xf50d94f5e24e646b6abb993c853b1dfd3571757c21de00f814668d1fc7ae082f",
}

DEFAULT_L1_ARGS = {
    # The L1 engine to use, either "geth" or "anvil".
    "l1_engine": "geth",
    # The L1 network identifier.
    "l1_chain_id": 271828,
    # This mnemonic will:
    # a) be used to create keystores for all the types of validators that we have, and
    # b) be used to generate a CL genesis.ssz that has the children validator keys already
    # preregistered as validators
    "l1_preallocated_mnemonic": "quit buddy poet only slide fitness sunny utility poem brave apart antique",
    # cast wallet private-key --mnemonic $l1_preallocated_mnemonic
    "l1_preallocated_private_key": "0x5122c3cea6263c6029f7468a513a42cf749a006b8bab573dcc710baa89141481",
    # The L1 HTTP RPC endpoint.
    "l1_rpc_url": "http://el-1-geth-lighthouse:8545",
    # The L1 WS RPC endpoint.
    "l1_ws_url": "ws://el-1-geth-lighthouse:8546",
    # The L1 concensus layer RPC endpoint.
    "l1_beacon_url": "http://cl-1-lighthouse-geth:4000",
    # The additional services to spin up.
    # Default: []
    # Options:
    #   - assertoor
    #   - broadcaster
    #   - tx_spammer
    #   - bridge_spammer
    #   - blob_spammer
    #   - custom_flood
    #   - goomy_blob
    #   - el_forkmon
    #   - blockscout
    #   - beacon_metrics_gazer
    #   - dora
    #   - full_beaconchain_explorer
    #   - prometheus_grafana
    #   - blobscan
    #   - dugtrio
    #   - blutgang
    #   - forky
    #   - apache
    #   - tracoor
    # Check the ethereum-package for more details: https://github.com/ethpandaops/ethereum-package
    "l1_additional_services": [],
    # Preset for the network.
    # Default: "mainnet"
    # Options:
    #   - mainnet
    #   - minimal
    # "minimal" preset will spin up a network with minimal preset. This is useful for rapid testing and development.
    # 192 seconds to get to finalized epoch vs 1536 seconds with mainnet defaults
    # Please note that minimal preset requires alternative client images.
    "l1_preset": "minimal",
    # Number of seconds per slot on the Beacon chain
    # Default: 12
    "l1_seconds_per_slot": 2,
    # Enable the Electra hardfork.
    "pectra_enabled": False,
    # The amount of ETH sent to the admin, sequence, aggregator, sequencer and other chosen addresses.
    "l1_funding_amount": "1000000ether",
    # Default: 2
    "l1_participants_count": 1,
    # Whether to deploy https://github.com/AggLayer/lxly-bridge-and-call
    "l1_deploy_lxly_bridge_and_call": True,
    # Anvil: l1_anvil_slots_in_epoch will set the gap of blocks finalized vs safe vs latest
    #   l1_anvil_block_time * l1_anvil_slots_in_epoch -> total seconds to transition a block from latest to safe
    # l1_anvil_block_time: seconds per block
    "l1_anvil_block_time": 1,
    # l1_anvil_slots_in_epoch: number of slots in an epoch
    "l1_anvil_slots_in_epoch": 1,
    # Set this to true if the L1 contracts for the rollup are already
    # deployed. This also means that you'll need some way to run
    # recovery from outside of kurtosis
    # TODO at some point it would be nice if erigon could recover itself, but this is not going to be easy if there's a DAC
    "use_previously_deployed_contracts": False,
    "erigon_datadir_archive": None,
    "anvil_state_file": None,
    "mitm_proxied_components": {
        "agglayer": False,
        "aggkit": False,
        "bridge": False,
        "dac": False,
        "erigon-sequencer": False,
        "erigon-rpc": False,
        "cdk-node": False,
    },
}

DEFAULT_L2_ARGS = {
    # The number of accounts to fund on L2. The accounts will be derived from:
    # polycli wallet inspect --mnemonic '{{.l1_preallocated_mnemonic}}'
    "l2_accounts_to_fund": 10,
    # The amount of ETH sent to each of the prefunded l2 accounts.
    "l2_funding_amount": "1000ether",
    # Whether to deploy https://github.com/Arachnid/deterministic-deployment-proxy.
    # Not deploying this will may cause errors or short circuit other contract
    # deployments.
    "l2_deploy_deterministic_deployment_proxy": True,
    # Whether to deploy https://github.com/AggLayer/lxly-bridge-and-call
    "l2_deploy_lxly_bridge_and_call": True,
    # This is used by erigon for naming the config files
    "chain_name": "kurtosis",
    # Config name for OP stack rollup
    "sovereign_chain_name": "op-sovereign",
    # TODO this seems like it comes from the op-succinct setup... we can probably get rid of this input
    # The minimum interval at which checkpoints must be submitted. No high security assumptions.
    "aggchain_submission_interval": 1,
}

DEFAULT_ROLLUP_ARGS = {
    # The keystore password.
    "zkevm_l2_keystore_password": "pSnv6Dh5s9ahuzGzH9RoCDrKAMddaX3m",
    # The rollup network identifier.
    "zkevm_rollup_chain_id": 9701,
    # The unique identifier for the rollup within the RollupManager contract.
    # This setting sets the rollup as the first rollup.
    "zkevm_rollup_id": 1,
    # By default a mock verifier is deployed.
    # Change to true to deploy a real verifier which will require a real prover.
    # Note: This will require a lot of memory to run!
    "zkevm_use_real_verifier": False,
    # If we're using pessimistic consensus and a real verifier, we'll
    # need to know which vkey to use. This value is tightly coupled to
    # the agglayer version that's being used
    # TODO automate this `docker run -it ghcr.io/agglayer/aggkit-prover:0.1.0-rc.8 aggkit-prover vkey`
    "aggchain_vkey_hash": "",
    # AggchainFEP, PolygonValidiumEtrog, PolygonZkEVMEtrog consensus requires programVKey === bytes32(0).
    # TODO automate this `docker run -it ghcr.io/agglayer/agglayer:0.3.0-rc.7 agglayer vkey`
    "pp_vkey_hash": constants.ZERO_HASH,
    # The 4 bytes selector to add to the pessimistic verification keys (AggLayerGateway)
    # TODO automate this `docker run -it ghcr.io/agglayer/agglayer:0.3.0-rc.7 agglayer vkey-selector`
    "pp_vkey_selector": "0x00000001",
    # Initial aggchain selector
    # TODO automate taking the first 2 bytes of this `docker run -it ghcr.io/agglayer/aggkit-prover:0.1.0-rc.8 aggkit-prover vkey-selector`
    "aggchain_vkey_version": "0x0000",
    # ForkID for the consensus contract. Must be 0 for AggchainFEP consensus.
    "fork_id": 12,
    # This flag will enable a stateless executor to verify the execution of the batches.
    # Set to true to run erigon as the sequencer.
    "erigon_strict_mode": True,
    # Set to true to use an L1 ERC20 contract as the gas token on the rollup.
    # The address of the gas token will be determined by the value of `gas_token_address`.
    "gas_token_enabled": False,
    # The address of the L1 ERC20 contract that will be used as the gas token on the rollup.
    # If the address is empty, a contract will be deployed automatically.
    "gas_token_address": constants.ZERO_ADDRESS,
    # The gas token origin network, to be used in BridgeL2SovereignChain.sol
    "gas_token_network": 0,
    # The sovereign WETH address, to be used in BridgeL2SovereignChain.sol
    "sovereign_weth_address": constants.ZERO_ADDRESS,
    # Flag to indicate if the wrapped ETH is not mintable, to be used in BridgeL2SovereignChain.sol
    "sovereign_weth_address_not_mintable": False,
    # Set to true to use Kurtosis dynamic ports (default) and set to false to use static ports.
    # You can either use the default static ports defined in this file or specify your custom static
    # ports.
    #
    # By default, Kurtosis binds the ports of enclave services to ephemeral or dynamic ports on the
    # host machine. To quote the Kurtosis documentation: "these ephemeral ports are called the
    # "public ports" of the container because they allow the container to be accessed outside the
    # Docker/Kubernetes cluster".
    # https://docs.kurtosis.com/advanced-concepts/public-and-private-ips-and-ports/
    "use_dynamic_ports": True,
    # Set this to true to disable all special logics in hermez and only enable bridge update in pre-block execution
    # https://hackmd.io/@4cbvqzFdRBSWMHNeI8Wbwg/r1hKHp_S0
    "enable_normalcy": False,
    # If the agglayer/aggkit-prover is going to use the network
    # prover, we'll need to provide an API Key Replace with a valid
    # SP1 key to use the SP1 Prover Network.
    "sp1_prover_key": "0xbcdf20249abf0ed6d944c0288fad489e33f66b3960d9e6229c1cd214ed3bbe31",
    # If we're setting an sp1 key, we might want to specify a specific RPC url as well
    "agglayer_prover_network_url": "https://rpc.production.succinct.xyz",
    # The type of primary prover to use in agglayer-prover. Note: if mock-prover is selected,
    # agglayer-node will also be configured with a mock verifier
    "agglayer_prover_primary_prover": "mock-prover",
    # The URL where the agglayer can be reached for gRPC
    "agglayer_grpc_url": "http://agglayer:"
    + str(DEFAULT_PORTS.get("agglayer_grpc_port")),
    # The URL where the agglayer can be reached for ReadRPC
    "agglayer_readrpc_url": "http://agglayer:"
    + str(DEFAULT_PORTS.get("agglayer_readrpc_port")),
    # The type of primary prover to use in aggkit-prover.
    "aggkit_prover_primary_prover": "mock-prover",
    # The URL where the aggkit-prover can be reached for gRPC
    "aggkit_prover_grpc_url": "aggkit-prover:"
    + str(DEFAULT_PORTS.get("aggkit_prover_grpc_port")),
    "zkevm_path_rw_data": "/tmp/",
    # OP Stack EL RPC URL. Will be dynamically updated by args_sanity_check() function.
    "op_el_rpc_url": "http://op-el-1-op-geth-op-node-001:8545",
    # OP Stack CL Node URL. Will be dynamically updated by args_sanity_check() function.
    "op_cl_rpc_url": "http://op-cl-1-op-node-op-geth-001:8547",
    # If the OP Succinct will use the Network Prover or CPU(Mock) Prover
    # true = mock
    # false = network
    "op_succinct_mock": False,
}

DEFAULT_PLESS_ZKEVM_NODE_ARGS = {
    "trusted_sequencer_node_uri": "zkevm-node-sequencer-001:6900",
    "zkevm_aggregator_host": "zkevm-node-aggregator-001",
    "genesis_file": "templates/permissionless-node/genesis.json",
    "sovereign_genesis_file": "templates/sovereign-genesis.json",
}

DEFAULT_ADDITIONAL_SERVICES_PARAMS = {
    "blockscout_params": {
        "blockscout_public_port": DEFAULT_PORTS.get("blockscout_frontend_port"),
    },
}

DEFAULT_ARGS = (
    {
        # Suffix appended to service names.
        # Note: It should be a string.
        "deployment_suffix": "-001",
        # Verbosity of the `kurtosis run` output.
        # Valid values are "error", "warn", "info", "debug", and "trace".
        # By default, the verbosity is set to "info". It won't log the value of the args.
        "verbosity": "info",
        # The global log level that all components of the stack should log at.
        # Valid values are "error", "warn", "info", "debug", and "trace".
        "global_log_level": "info",
        "aggkit_prover_log_level": "info",
        # The type of the sequencer to deploy.
        # Options:
        # - 'erigon': Use the new sequencer (https://github.com/0xPolygonHermez/cdk-erigon).
        # - 'zkevm': Use the legacy sequencer (https://github.com/0xPolygonHermez/zkevm-node).
        "sequencer_type": "erigon",
        # The type of consensus contract to use.
        # Consensus Options:
        # - 'rollup': Transaction data is stored on-chain on L1.
        # - 'cdk-validium': Transaction data is stored off-chain using the CDK DA layer and a DAC.
        # - 'pessimistic': deploy with pessimistic consensus
        # Aggchain Consensus Options:
        # - 'ecdsa': Aggchain using an ECDSA signature with CONSENSUS_TYPE = 1.
        # - 'fep': Generic aggchain using Full Execution Proofs that relies on op-succinct stack.
        "consensus_contract_type": constants.CONSENSUS_TYPE.cdk_validium,
        # Additional services to run alongside the network.
        # Options:
        # - arpeggio
        # - assertoor
        # - blockscout
        # - blutgang
        # - bridge_spammer
        # - erpc
        # - observability
        # - pless_zkevm_node
        # - status_checker
        # - test_runner
        # - tx_spammer
        "additional_services": [constants.ADDITIONAL_SERVICES.test_runner],
        # Only relevant when deploying to an external L1.
        "polygon_zkevm_explorer": "https://explorer.private/",
        "l1_explorer_url": "https://sepolia.etherscan.io/",
    }
    | DEFAULT_IMAGES
    | DEFAULT_PORTS
    | DEFAULT_ACCOUNTS
    | DEFAULT_L1_ARGS
    | DEFAULT_ROLLUP_ARGS
    | DEFAULT_PLESS_ZKEVM_NODE_ARGS
    | DEFAULT_L2_ARGS
    | DEFAULT_ADDITIONAL_SERVICES_PARAMS
)

# https://github.com/ethpandaops/optimism-package
# The below OP params can be customized by specifically referring to an artifact or image.
# If none is is provided, it will refer to the default images from the Optimism-Package repo.
# https://github.com/ethpandaops/optimism-package/blob/main/src/package_io/input_parser.star
DEFAULT_OP_STACK_ARGS = {
    "source": "github.com/ethpandaops/optimism-package/main.star@884f4eb813884c4c8e5deead6ca4e0c54b85da90",
    "predeployed_contracts": False,
    "chains": [
        {
            "participants": [
                {
                    # OP Rollup configuration
                    "el_type": "op-geth",
                    "el_image": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:v1.101500.0-rc.3",
                    "cl_type": "op-node",
                    "cl_image": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:v1.11.0-rc.2",
                    "count": 1,
                },
            ],
            "network_params": {
                # name maps to l2_services_suffix in optimism. The optimism-package appends a suffix with the following format: -<name>
                # the "-" however adds another "-" to the Kurtosis deployment_suffix. So we are doing string manipulation to remove the "-"
                "name": DEFAULT_ARGS.get("deployment_suffix")[1:],
                "network_id": str(DEFAULT_ROLLUP_ARGS.get("zkevm_rollup_chain_id")),
                # The blocktime on the OP network
                "seconds_per_slot": 1,
            },
        },
    ],
}

VALID_ADDITIONAL_SERVICES = [
    getattr(constants.ADDITIONAL_SERVICES, field)
    for field in dir(constants.ADDITIONAL_SERVICES)
]

# A list of fork identifiers currently supported by Kurtosis CDK.
SUPPORTED_FORK_IDS = [9, 11, 12, 13]

VALID_CONSENSUS_TYPES = [
    constants.CONSENSUS_TYPE.rollup,
    constants.CONSENSUS_TYPE.cdk_validium,
    constants.CONSENSUS_TYPE.pessimistic,
    constants.CONSENSUS_TYPE.fep,
    constants.CONSENSUS_TYPE.ecdsa,
]


def parse_args(plan, user_args):
    # Merge the provided args with defaults.
    deployment_stages = DEFAULT_DEPLOYMENT_STAGES | user_args.get(
        "deployment_stages", {}
    )
    op_stack_args = user_args.get("optimism_package", {})
    args = DEFAULT_ARGS | user_args.get("args", {})

    # Change some params if anvil set to make it work
    # As it changes L1 config it needs to be run before other functions/checks
    set_anvil_args(plan, args, user_args)

    # Determine OP stack args.
    op_stack_args = get_op_stack_args(plan, args, op_stack_args)

    # Sanity check step for incompatible parameters
    args_sanity_check(plan, deployment_stages, args, user_args, op_stack_args)

    validate_consensus_type(args.get("consensus_contract_type"))
    validate_vkeys(plan, args, deployment_stages)

    # Setting mitm for each element set to true on mitm dict
    mitm_rpc_url = (
        "http://mitm"
        + args["deployment_suffix"]
        + ":"
        + str(DEFAULT_PORTS.get("mitm_port"))
    )
    args["mitm_rpc_url"] = {
        k: mitm_rpc_url for k, v in args.get("mitm_proxied_components", {}).items() if v
    }

    # Validation step.
    verbosity = args.get("verbosity", "")
    validate_log_level("verbosity", verbosity)

    global_log_level = args.get("global_log_level", "")
    validate_log_level("global log level", global_log_level)

    validate_additional_services(args.get("additional_services", []))

    # Determine fork id from the zkevm contracts image tag.
    zkevm_contracts_image = args.get("zkevm_contracts_image", "")
    (fork_id, fork_name) = get_fork_id(zkevm_contracts_image)

    # Determine sequencer and l2 rpc names.
    sequencer_type = args.get("sequencer_type", "")
    sequencer_name = get_sequencer_name(sequencer_type)

    deploy_cdk_erigon_node = deployment_stages.get("deploy_cdk_erigon_node", False)
    deploy_op_node = deployment_stages.get("deploy_optimism_rollup", False)
    l2_rpc_name = get_l2_rpc_name(deploy_cdk_erigon_node, deploy_op_node)

    # Determine static ports, if specified.
    if not args.get("use_dynamic_ports", True):
        plan.print("Using static ports.")
        args = DEFAULT_STATIC_PORTS | args

    # When using assertoor to test L1 scenarios, l1_preset should be mainnet for deposits and withdrawls to work.
    if "assertoor" in args["l1_additional_services"]:
        plan.print(
            "Assertoor is detected - changing l1_preset to mainnet and l1_participant_count to 2"
        )
        args["l1_preset"] = "mainnet"
        args["l1_participant_count"] = 2

    # Remove deployment stages from the args struct.
    # This prevents updating already deployed services when updating the deployment stages.
    if "deployment_stages" in args:
        args.pop("deployment_stages")

    args = args | {
        "l2_rpc_name": l2_rpc_name,
        "sequencer_name": sequencer_name,
        "zkevm_rollup_fork_id": fork_id,
        "zkevm_rollup_fork_name": fork_name,
        "deploy_agglayer": deployment_stages.get(
            "deploy_agglayer", False
        ),  # hacky but works fine for now.
    }

    # Sort dictionaries for debug purposes.
    sorted_deployment_stages = dict.sort_dict_by_values(deployment_stages)
    sorted_args = dict.sort_dict_by_values(args)
    sorted_op_stack_args = dict.sort_dict_by_values(op_stack_args)
    return (sorted_deployment_stages, sorted_args, sorted_op_stack_args)


def validate_log_level(name, log_level):
    if log_level not in (
        constants.LOG_LEVEL.error,
        constants.LOG_LEVEL.warn,
        constants.LOG_LEVEL.info,
        constants.LOG_LEVEL.debug,
        constants.LOG_LEVEL.trace,
    ):
        fail(
            "Unsupported {}: '{}', please use '{}', '{}', '{}', '{}' or '{}'".format(
                name,
                log_level,
                constants.LOG_LEVEL.error,
                constants.LOG_LEVEL.warn,
                constants.LOG_LEVEL.info,
                constants.LOG_LEVEL.debug,
                constants.LOG_LEVEL.trace,
            )
        )


def validate_additional_services(additional_services):
    for svc in additional_services:
        if svc not in VALID_ADDITIONAL_SERVICES:
            fail(
                "Unsupported additional service: '{}', please use one of: '{}'".format(
                    svc, VALID_ADDITIONAL_SERVICES
                )
            )


def get_fork_id(zkevm_contracts_image):
    """
    Extract the fork identifier and fork name from a zkevm contracts image name.

    The zkevm contracts tags follow the convention:
    v<SEMVER>-rc.<RC_NUMBER>-fork.<FORK_ID>[-patch.<PATCH_NUMBER>]

    Where:
    - <SEMVER> is the semantic versioning (MAJOR.MINOR.PATCH).
    - <RC_NUMBER> is the release candidate number.
    - <FORK_ID> is the fork identifier.
    - -patch.<PATCH_NUMBER> is optional and represents the patch number.

    Example:
    - v8.0.0-rc.2-fork.12
    - v7.0.0-rc.1-fork.10
    - v7.0.0-rc.1-fork.11-patch.1
    """
    result = zkevm_contracts_image.split("-patch.")[0].split("-fork.")
    if len(result) != 2:
        fail(
            "The zkevm contracts image tag '{}' does not follow the standard v<SEMVER>-rc.<RC_NUMBER>-fork.<FORK_ID>".format(
                zkevm_contracts_image
            )
        )

    fork_id = int(result[1])
    if fork_id not in SUPPORTED_FORK_IDS:
        fail("The fork id '{}' is not supported by Kurtosis CDK".format(fork_id))

    fork_name = "elderberry"
    if fork_id >= 12:
        fork_name = "banana"
    # TODO: Add support for durian once released.

    return (fork_id, fork_name)


def get_sequencer_name(sequencer_type):
    if sequencer_type == constants.SEQUENCER_TYPE.CDK_ERIGON:
        return "cdk-erigon-sequencer"
    elif sequencer_type == constants.SEQUENCER_TYPE.ZKEVM:
        return "zkevm-node-sequencer"
    else:
        fail(
            "Unsupported sequencer type: '{}', please use '{}' or '{}'".format(
                sequencer_type,
                constants.SEQUENCER_TYPE.CDK_ERIGON,
                constants.SEQUENCER_TYPE.ZKEVM,
            )
        )


def get_l2_rpc_name(deploy_cdk_erigon_node, deploy_op_node):
    if deploy_op_node:
        return "op-el-1-op-geth-op-node"
    if deploy_cdk_erigon_node:
        return "cdk-erigon-rpc"
    return "zkevm-node-rpc"


def get_op_stack_args(plan, args, user_op_stack_args):
    op_stack_args = DEFAULT_OP_STACK_ARGS | user_op_stack_args

    l1_chain_id = str(args.get("l1_chain_id", ""))
    l1_rpc_url = args.get("l1_rpc_url", "")
    l1_ws_url = args.get("l1_ws_url", "")
    l1_beacon_url = args.get("l1_beacon_url", "")

    l1_preallocated_mnemonic = args.get("l1_preallocated_mnemonic", "")
    private_key_result = plan.run_sh(
        description="Deriving the private key from the mnemonic",
        run="cast wallet private-key --mnemonic \"{}\" | tr -d '\n'".format(
            l1_preallocated_mnemonic
        ),
        image=constants.TOOLBOX_IMAGE,
    )
    private_key = private_key_result.output

    source = op_stack_args.pop("source")
    predeployed_contracts = op_stack_args.pop("predeployed_contracts")

    return {
        "source": source,
        "predeployed_contracts": predeployed_contracts,
        "optimism_package": op_stack_args,
        "external_l1_network_params": {
            "network_id": l1_chain_id,
            "rpc_kind": "standard",
            "el_rpc_url": l1_rpc_url,
            "el_ws_url": l1_ws_url,
            "cl_rpc_url": l1_beacon_url,
            "priv_key": private_key,
        },
    }


def set_anvil_args(plan, args, user_args):
    if args["anvil_state_file"] != None:
        if user_args.get("args", {}).get("l1_engine") != "anvil":
            args["l1_engine"] = "anvil"
            plan.print("Anvil state file detected - changing l1_engine to anvil")

    if args["l1_engine"] == "anvil":
        # We override only is user did not provide explicit values
        if not user_args.get("args", {}).get("l1_rpc_url"):
            args["l1_rpc_url"] = (
                "http://anvil"
                + args["deployment_suffix"]
                + ":"
                + str(DEFAULT_PORTS.get("anvil_port"))
            )
        if not user_args.get("args", {}).get("l1_ws_url"):
            args["l1_ws_url"] = (
                "ws://anvil"
                + args["deployment_suffix"]
                + ":"
                + str(DEFAULT_PORTS.get("anvil_port"))
            )
        if not user_args.get("args", {}).get("l1_beacon_url"):
            args["l1_beacon_url"] = (
                "http://anvil"
                + args["deployment_suffix"]
                + ":"
                + str(DEFAULT_PORTS.get("anvil_port"))
            )


# Helper function to compact together checks for incompatible parameters in input_parser.star
def args_sanity_check(plan, deployment_stages, args, user_args, op_stack_args):
    # Fix the op stack el rpc urls according to the deployment_suffix.
    if args["op_el_rpc_url"] != "http://op-el-1-op-geth-op-node" + args[
        "deployment_suffix"
    ] + ":8545" and deployment_stages.get("deploy_op_stack", False):
        plan.print(
            "op_el_rpc_url is set to '{}', changing to 'http://op-el-1-op-geth-op-node{}:8545'".format(
                args["op_el_rpc_url"], args["deployment_suffix"]
            )
        )
        args["op_el_rpc_url"] = (
            "http://op-el-1-op-geth-op-node" + args["deployment_suffix"] + ":8545"
        )
    # Fix the op stack cl rpc urls according to the deployment_suffix.
    if args["op_cl_rpc_url"] != "http://op-cl-1-op-node-op-geth" + args[
        "deployment_suffix"
    ] + ":8547" and deployment_stages.get("deploy_op_stack", False):
        plan.print(
            "op_cl_rpc_url is set to '{}', changing to 'http://op-cl-1-op-node-op-geth{}:8547'".format(
                args["op_cl_rpc_url"], args["deployment_suffix"]
            )
        )
        args["op_cl_rpc_url"] = (
            "http://op-cl-1-op-node-op-geth" + args["deployment_suffix"] + ":8547"
        )
    # The optimism-package network_params is a frozen hash table, and is not modifiable during runtime.
    # The check will return fail() instead of dynamically changing the network_params name.
    if op_stack_args["optimism_package"]["chains"][0]["network_params"]["name"] != args[
        "deployment_suffix"
    ][1:] and deployment_stages.get("deploy_op_stack", False):
        fail(
            "op_stack_args network_params name is set to '{}', please change it to match deployment_suffix '{}'".format(
                op_stack_args["optimism_package"]["chains"][0]["network_params"][
                    "name"
                ],
                args["deployment_suffix"][1:],
            )
        )

    # Check args[zkevm_rollup_chain_id] and op_stack_args["optimism_package"]["chains"][0]["network_params"]["network_id"] are equal.
    if str(args["zkevm_rollup_chain_id"]) != str(
        op_stack_args["optimism_package"]["chains"][0]["network_params"]["network_id"]
    ) and deployment_stages.get("deploy_op_stack", False):
        fail(
            "op_stack_args network_params network_id is set to '{}', please change it to match zkevm_rollup_chain_id '{}'".format(
                op_stack_args["optimism_package"]["chains"][0]["network_params"][
                    "network_id"
                ],
                args["zkevm_rollup_chain_id"],
            )
        )

    # Unsupported L1 engine check
    if args["l1_engine"] not in constants.L1_ENGINES:
        fail(
            "Unsupported L1 engine: '{}', please use one of {}".format(
                args["l1_engine"], constants.L1_ENGINES
            )
        )

    # Gas token check
    if args.get("gas_token_enabled", False):
        # Ensure gas token is not used with OP Rollup.
        if deployment_stages.get("deploy_optimism_rollup", False):
            fail("Gas token is not supported when deploying OP Rollup.")

    # CDK Erigon normalcy and strict mode check
    if args["enable_normalcy"] and args["erigon_strict_mode"]:
        fail("normalcy and strict mode cannot be enabled together")

    # OP rollup deploy_optimistic_rollup and consensus_contract_type check
    if deployment_stages.get("deploy_optimism_rollup", False):
        if args["consensus_contract_type"] != constants.CONSENSUS_TYPE.pessimistic:
            if args["consensus_contract_type"] != "fep":
                plan.print(
                    "Current consensus_contract_type is '{}', changing to pessimistic for OP deployments.".format(
                        args["consensus_contract_type"]
                    )
                )
                # TODO: should this be AggchainFEP instead?
                args["consensus_contract_type"] = constants.CONSENSUS_TYPE.pessimistic

    # If OP-Succinct is enabled, OP-Rollup must be enabled
    if deployment_stages.get("deploy_op_succinct", False):
        if deployment_stages.get("deploy_optimism_rollup", False) == False:
            fail(
                "OP Succinct requires OP Rollup to be enabled. Change the deploy_optimism_rollup parameter"
            )
        if args["sp1_prover_key"] == None or args["sp1_prover_key"] == "":
            fail("OP Succinct requires a valid SPN key. Change the sp1_prover_key")

    # OP rollup check L1 blocktime >= L2 blocktime
    op_network_params = op_stack_args["optimism_package"]["chains"][0]["network_params"]
    if deployment_stages.get("deploy_optimism_rollup", False):
        if args.get("l1_seconds_per_slot", 12) < op_network_params.get(
            "seconds_per_slot", 1
        ):
            fail(
                "OP Stack rollup requires L1 blocktime > 1 second. Change the l1_seconds_per_slot parameter"
            )

    # Sanity checking and overwriting input parameters for cdk-validium consensus with supported inputs.
    consensus_contract_type = args.get("consensus_contract_type")
    if consensus_contract_type in [
        constants.CONSENSUS_TYPE.rollup,
        constants.CONSENSUS_TYPE.cdk_validium,
    ]:
        if "v10" in args["zkevm_contracts_image"]:
            plan.print(
                "For '{}' consensus, the zkevm_contracts_image should be \"leovct/zkevm-contracts:v10.0.0-rc.3-fork.12\". Changing...".format(
                    args["consensus_contract_type"]
                )
            )
            args[
                "zkevm_contracts_image"
            ] = "leovct/zkevm-contracts:v10.0.0-rc.3-fork.12"

    # FIXME - I've removed some code here that was doing some logic to
    # update the vkeys depending on the consensus. We either need to
    # have different vkeys depending on the context (e.g. if we're
    # deploying the rollpu manager it needs to be set
    # (VKeyCannotBeZero() 0x6745305e), but if we're creating an
    # aggchainFEP it must not be set) or we can hard code to be
    # 0x000...000 in the situations where we know it must be zero


def validate_consensus_type(consensus_type):
    if consensus_type not in VALID_CONSENSUS_TYPES:
        fail(
            'Invalid consensus type: "{}". Allowed value(s): {}.'.format(
                consensus_type, VALID_CONSENSUS_TYPES
            )
        )


def validate_vkeys(plan, args, deployment_stages):
    consensus_type = args.get("consensus_contract_type")

    # For rollup and cdk-validium consensus, ensure the pp vkey is set to the zero hash.
    if consensus_type in [
        constants.CONSENSUS_TYPE.rollup,
        constants.CONSENSUS_TYPE.cdk_validium,
    ]:
        pp_vkey = args.get("pp_vkey_hash")
        if pp_vkey != constants.ZERO_HASH:
            fail(
                "For rollup and cdk-validium consensus, the pp_vkey_hash must be set to '{}', but got '{}'.".format(
                    constants.ZERO_HASH, pp_vkey
                )
            )

    # For pessimistic consensus, ensure the pp vkey matches the value returned by the agglayer binary.
    # Only validate the aggchain vkey if an OP rollup is deployed.
    if consensus_type == constants.CONSENSUS_TYPE.pessimistic:
        validate_pp_vkey_with_binary(
            plan,
            pp_vkey=args.get("pp_vkey_hash"),
            agglayer_image=args.get("agglayer_image"),
        )

        if deployment_stages.get("deploy_optimism_rollup", False):
            validate_aggchain_vkey_with_binary(
                plan,
                aggchain_vkey=args.get("aggchain_vkey_hash"),
                aggkit_prover_image=args.get("aggkit_prover_image"),
            )

    # For aggchain consensus, ensure the vkeys match the expected values returned by the binaries.
    if consensus_type in [
        constants.CONSENSUS_TYPE.ecdsa,
        constants.CONSENSUS_TYPE.fep,
    ]:
        validate_pp_vkey_with_binary(
            plan,
            pp_vkey=args.get("pp_vkey_hash"),
            agglayer_image=args.get("agglayer_image"),
        )
        validate_aggchain_vkey_with_binary(
            plan,
            aggchain_vkey=args.get("aggchain_vkey_hash"),
            aggkit_prover_image=args.get("aggkit_prover_image"),
        )


def validate_pp_vkey_with_binary(plan, pp_vkey, agglayer_image):
    result = plan.run_sh(
        name="agglayer-vkey-getter",
        description="Getting agglayer vkey",
        image=agglayer_image,
        run="agglayer vkey | tr -d '\n'",
    )
    plan.verify(
        description="Verifying agglayer vkey",
        value=result.output,
        assertion="==",
        target_value=pp_vkey,
    )


def validate_aggchain_vkey_with_binary(plan, aggchain_vkey, aggkit_prover_image):
    result = plan.run_sh(
        name="aggkit-prover-vkey-getter",
        description="Getting aggkit prover vkey",
        image=aggkit_prover_image,
        run="aggkit-prover vkey | tr -d '\n'",
    )
    plan.verify(
        description="Verifying aggkit prover vkey",
        # FIXME: At some point in the future, the aggchain vkey hash will probably come prefixed with 0x and we'll need to fix this.
        value="0x{}".format(result.output),
        assertion="==",
        target_value=aggchain_vkey,
    )
