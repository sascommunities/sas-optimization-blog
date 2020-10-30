# Venue Optimization

This repository includes a simplified version of SAS Venue Optimization.

The purpose of Venue Optimization is to maximize number of viewers or to maximize the total revenue for seated venues while adhering to COVID-19 social distancing regulations. We use a mathematical formulation to optimize seating plans for venue management.

## Mathmetical Model

Optimization process inside Venue Optimization consists of two parts:

1. Finding all the cliques of seating groups that cannot be sold at the same time. This could be due to proximity or infeasibility.
2. Finding all groups to offer to customers, which maximizes the utilization or the revenue.

First part is solved using [SAS Optimization](https://www.sas.com/en_us/software/optimization.html)'s [network solver](https://documentation.sas.com/?cdcId=pgmsascdc&cdcVersion=9.4_3.5&docsetId=casmopt&docsetTarget=casmopt_networksolver_overview.htm&locale=en):

``` sas
solve with network / links=(include=CONFLICTS) clique=(maxcliques=all) out=(cliques=ID_NODE);
```

Here, `CONFLICTS` is the set of group pairs which cannot be selected either due to social distancing or due to overlapping.
The output `ID_NODE` is a set, where each member represents a clique. Then, we solve the following model using SAS Optimization [mixed-integer linear optimization solver](https://documentation.sas.com/?cdcId=pgmsascdc&cdcVersion=9.4_3.5&docsetId=casmopt&docsetTarget=casmopt_milpsolver_overview.htm&locale=en):

<p align="center">
<img src="https://latex.codecogs.com/gif.latex?%5Cbegin%7Barray%7D%7Blrlll%7D%20%5Ctext%7Bmaximize%7D%20%26%20%5Cdisplaystyle%20%5Csum_%7Bg%20%5Cin%20G%7D%20n_g%20u_g%20%5C%5C%20%5Ctext%7Bsubject%20to%7D%20%26%20%5Cdisplaystyle%20%5Csum_%7Bg%20%5Cin%20G_c%7D%20u_g%20%26%20%5Cle%201%20%26%20%5C%3B%20%5Ctext%7Bfor%20%7D%20c%20%5Cin%20C%20%5C%5C%20%26%20u_g%20%26%20%5Cin%20%5C%7B0%2C%201%5C%7D%20%26%20%5C%3B%20%5Ctext%7Bfor%20%7D%20g%20%5Cin%20G%20%5Cend%7Barray%7D" />
</p>

Here, `G` is the set of all possible groups in the section, `C` is the set of maximal cliques such that at most one group in each clique can be selected, `d` is the distance parameter between each pair of groups, and `t` is the social distancing limit. `n_g` is the number of people in group `g` and `u_g` is a binary decision variable that indicates whether group `g` is selected.

We use call the mixed integer linear optimization solver as follows:

``` sas
solve with milp;
create data solution_venue from [i]={i in GROUPS: x[i].sol > 0.5} var=x[i].name price=group_price value=x[i].sol;
```

## Running the instance

In order to use this repository, you need to have access to a SAS Viya deployment with SAS Optimization.

1. Edit ".env.sample" using your credentials and save it as ".env" in the main directory.

2. Install dependencies:
   ``` shell
   pip install pandas swat
   ```

3. Run
   ``` python
   python solve.py
   ```
   This script will use `data/input.csv` file as an input and you will see the optimal selection of groups under `data` folder.
   
   You can also create a Docker image using the Dockerfile:

   ``` shell
   docker build -t venue_optimization .
   docker run --rm -v data:/app/data venue_optimization
   ```

The solution will be saved under `data/output.json` as a JSON file as a list.
Each list member is a list of seats (row, seat number) in that particular group.

## Visualization

Check the Jupyter notebook on [nbviewer](https://nbviewer.jupyter.org/github/sertalpbilal/sas-optimization-blog/blob/master/venue_optimization/notebook/Venue%20Optimization.ipynb) for a simple visualization.

## License

This work is published under Apache 2.0 license. See [LICENSE](LICENSE.md) for details.
