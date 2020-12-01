import sys
import re
import collections
from statistics import median

# order listed here determines print output order
algonames = [
    "weakly connected components",
    "strongly connected components",
    "biconnected components",
    "spanning forest",
    "weighted spanning forest",
    "single shortest path",
    "weighted single shortest path",
    "kcore",
    "local clustering coefficient",
    "clique",
    "pagerank",
    "weighted pagerank",
    "betweenness centrality",
    "weighted betweenness centrality",
    "closeness centrality",
    "weighted closeness centrality",
    "jaccard similarity"
]
datasets = [
    "email-Enron.txt",
    "soc-Epinions1.txt",
    "web-Google.txt",
    "soc-pokec-relationships.txt",
    "com-orkut.ungraph.txt",
    "wikipedia_link_en.txt"
]

elapsed = collections.defaultdict(list)
total = collections.defaultdict(list)
with open(sys.argv[1], "r") as fin:
    lines = fin.readlines()

algo = None
graph = None
for line in lines:
    t = re.findall("(.*), (.*), (.*), (nThreads=\d+)", line)
    if len(t) > 0:
        lib, algo, graph, nthreads = t[0]
        if graph.endswith("_weighted.txt"):
            graph = graph.rsplit("_weighted.", 1)[0] + ".txt"

    if "algo  elapsed" in line:
        t = "nan"
        if not "nan" in line:
            t = re.findall(r"(\d+\.\d+)", line)[0]
        elapsed[(algo, graph)].append(t)

    if "total elapsed" in line:
        t = "nan"
        if not "nan" in line:
            t = re.findall(r"(\d+\.\d+)", line)[0]
        total[(algo, graph)].append(t)


for algo in algonames:
    for graph in datasets:
        if not (algo, graph) in total:
            continue
        atimes = elapsed[(algo, graph)]
        ttimes = total[(algo, graph)]

        i = ttimes.index(median(ttimes))
        print(f"{atimes[i]},{ttimes[i]}")
