import os
import sys
import re
import math
import pandas as pd
import random
import swat
import argparse
from io import StringIO

random.seed(1234)


def take_input():
    parser = argparse.ArgumentParser()
    parser.add_argument("filepath", type=str, help="filepath of dataset to run")
    parser.add_argument("--nthreads", type=int, default=8, help="number of threads to use")
    parser.add_argument("--weighted", action='store_true', help="whether grap is weighted")
    parser.add_argument("--nsources", type=int, default=10, help="number of source nodes to run sssp over")

    return parser.parse_args()


def print_header(package, algorithm, dataset, nthreads=1):
    dataset = dataset.rsplit("/", 1)[1]
    wtext = "weighted " if dataset.endswith("_weighted.txt") else ""
    header = f"{package}, {wtext}{algorithm}, {dataset}, nThreads={nthreads}"
    print(header)
    print("="*len(header))


def print_results(build_elapsed, algo_elapsed, tot_elapsed=None, other={}):
    sys.stdout = sys.__stdout__  # set to true stdout in case changed

    if build_elapsed is None:
        build_elapsed = math.nan
    if algo_elapsed is None:
        algo_elapsed = math.nan

    if tot_elapsed is None:
        tot_elapsed = build_elapsed + algo_elapsed

    print(f"  build elapsed:  {build_elapsed:.3f}")
    print(f"  algo  elapsed:  {algo_elapsed:.3f}")
    print(f"  total elapsed:  {tot_elapsed:.3f}")

    for key, value in other.items():
        print(f"  {key}:  {value}")
    print()


def init_sas(filename, casrc_path="../casrc.txt"):
    casrc_path = os.path.join(os.path.dirname(os.path.realpath(__file__)), casrc_path)
    casrc = None
    with open(casrc_path, "r") as fin:
        casrc = fin.read()

    host = re.findall("HOST=(.+)", casrc)[0]
    port = re.findall("PORT=(\d+)", casrc)[0]

    session = swat.CAS(host, port)
    sys.stdout = StringIO()
    session.setsessopt(metrics=True, maxtablemem=0)  # maxtablemem is required to stop disk writes on big tables
    swat.options.cas.print_messages = True

    session.loadactionset(actionset="table")
    session.loadactionset(actionset="network")
    session.loadactionset(actionset="optnetwork")

    folder = filename.rsplit("/", 1)[0]
    session.addcaslib(caslib="data", datasource={"srctype": "path"},
                      path=folder, activeOnAdd=False)

    gfile = filename.rsplit("/", 1)[1]
    session.loadTable(caslib="data", path=gfile, casout={"name": "links"}, importOptions={
                      "filetype": "csv", "delimiter": "\t", "getNames": False})

    session.alterTable(name="links", columns=[{"name": "Var1", "rename": "from"}, {"name": "Var2", "rename": "to"}])
    nCols = len(session.fetch(table={"name": "links"}, maxRows=1)["Fetch"].columns)
    if nCols > 2:
        session.alterTable(name="links", columns=[{"name": "Var3", "rename": "weight"}])

    return session


def parse_sas_log(log_path="../saslogs.txt"):
    log = sys.stdout.getvalue()

    # save SAS client log to file
    log_path = os.path.join(os.path.dirname(os.path.realpath(__file__)), log_path)
    file = open(log_path, "a")
    file.write(log)
    file.write("\n\n\n")
    file.close()

    # return runtime results
    build_elapsed = 0.0
    build_elapsed += float(re.findall("NOTE: Data input used (\d+\.\d+)", log)[0])
    build_elapsed += float(re.findall("NOTE: Building the input graph storage used (\d+\.\d+)", log)[0])
    algo_elapsed = float(re.findall("NOTE: Processing .* used (\d+\.\d+) .* seconds", log)[-1])

    sys.stdout = StringIO()  # reset the log in case we are doing multiple iterations in same session

    return build_elapsed, algo_elapsed


def terminate_sas(session, tot_elapsed, other={}, elapsed=None):
    session.endsession()
    if elapsed is None:
        elapsed = parse_sas_log()
    print_results(*elapsed, tot_elapsed, other=other)


def random_pairs(upperbound, npairs):
    l = random.sample(range(upperbound), npairs*2)
    return [(l[i], l[i+1]) for i in range(0, len(l), 2)]


def generate_sources(n, session, tablename="links"):
    table = session.CASTable("links")
    nnodes = int(max(table["from"].max(), table["to"].max())) + 1

    return random.sample(range(nnodes), n)


def read_st_pairs(filename):
    pairs = []
    with open(filename, "r") as fin:
        for line in fin:
            s, t = line.strip().split("\t")
            pairs.append((int(s), int(t)))
    return pairs
