import time
import helper

args = helper.take_input()
helper.print_header("sas-network", "betweenness centrality", args.filepath, args.nthreads)

session = helper.init_sas(args.filepath)

if args.weighted:
    session.alterTable(name="links", columns=[{"name": "weight", "rename": "weight2"}])

st = time.time()
session.network.centrality(
    nThreads=args.nthreads,
    logLevel="aggressive",
    direction="directed",
    linksVar={"auxweight": "weight2"} if args.weighted else {},
    links={"name": "links"},
    between="weight" if args.weighted else "unweight",
    betweenNorm=False,
    outNodes={"name": "outNodes", "replace": True},
    outLinks={"name": "outLinks", "replace": True})
tot_elapsed = time.time() - st

helper.terminate_sas(session, tot_elapsed)
