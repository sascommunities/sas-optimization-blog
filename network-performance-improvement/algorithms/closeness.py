import time
import helper

args = helper.take_input()
helper.print_header("sas-network", "closeness centrality", args.filepath, args.nthreads)

session = helper.init_sas(args.filepath)

if args.weighted:
    session.alterTable(name="links", columns=[{"name": "weight", "rename": "weight2"}])

st = time.time()
session.network.centrality(
    nthreads=args.nthreads,
    logLevel="aggressive",
    linksVar={"auxweight": "weight2"} if args.weighted else {},
    links={"name": "links"},
    close="weight" if args.weighted else "unweight",
    closeNoPath="zero",
    outNodes={"name": "outNodes", "replace": True})
tot_elapsed = time.time() - st

helper.terminate_sas(session, tot_elapsed)
