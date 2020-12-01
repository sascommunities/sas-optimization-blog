import time
import helper

args = helper.take_input()
helper.print_header("sas-network", "single shortest path", args.filepath, args.nthreads)

session = helper.init_sas(args.filepath)

tot_elapsed = 0.0
build_elapsed = 0.0
algo_elapsed = 0.0

for v in helper.generate_sources(args.nsources, session):
    st = time.time()
    session.network.shortestPath(
        nthreads=args.nthreads,
        logLevel="aggressive",
        links={"name": "links"},
        outWeights={"name": "out", "replace": True},
        source=v)
    tot_elapsed += time.time() - st

    b, a = helper.parse_sas_log()
    build_elapsed += b
    algo_elapsed += a

build_elapsed = build_elapsed / args.nsources
algo_elapsed = algo_elapsed / args.nsources
tot_elapsed = tot_elapsed / args.nsources

helper.terminate_sas(session, tot_elapsed, elapsed=(build_elapsed, algo_elapsed))
