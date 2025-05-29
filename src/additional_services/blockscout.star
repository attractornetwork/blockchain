blockscout_package = import_module(
    "github.com/attractornetwork/transaction-explorer/main.star@master"
)
service_package = import_module("../../lib/service.star")


def run(plan, args):
    l2_rpc_url = service_package.get_l2_rpc_url(plan, args)

    blockscout_params = {
        "chain_id": "str(args["zkevm_rollup_chain_id"])",
        "deployment_suffix": args["deployment_suffix"],
        "rpc_url": "rpc.testnet.attra.me",
        "trace_url": "rpc.testnet.attra.me",
        "ws_url": "rpc.testnet.attra.me",
        "blockscout_public_ip": "explorer.testnet.attra.me",
        "blockscot_backend_port": 50102,
        "swap_url": "bridge.testnet.attra.me",
        "l1_explorer": "sepolia.etherscan.io",
        "bridge_info": {
            "l1_network_id": 11155111,
            "l2_network_id": 9701,
        }
    } | args.get("blockscout_params", {})

    blockscout_package.run(plan, args=blockscout_params)
