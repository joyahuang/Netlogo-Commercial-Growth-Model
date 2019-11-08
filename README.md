# Netlogo-Commercial-Growth-Model
Team: Zhuoya Huang, Yanhan Pan, Zichen Liu. Tutor: Wei Zhu.
## Introductory
In urban planning, the commercial facilities planning is of top importance. By NetLogo simulation, we can control the influence of all kinds of influence factors to determine the location and scale of urban commercial facilities, so as to provide reference for planning and design.

## Model
First, we divide influential factors into the following categories: commercial cluster degree, commercial potential, store history, openness, road type, land use, agent commute purpose. Agents will consume a certain amount of money and time at a certain store based on their commute purpose, simulating profit and loss. In the meantime, store rent also can change with turnover profit. The death and life of stores are determined by two factors: store net profit and rent. If the net profit is greater than the rent, the store can survive, and vice versa. In the process of executing the program, the weight of each factor can be adjusted to simulate the commercial growth model in different situations.

## Concept in the model
### Agent:persons
Property|Explanation
-|-
money|agents' remaining money.
goal|The destination of agent commuting action
goalnode|The node of the intersection that is the nearest to their goal
alongpoints|The nodes along the shortest path to goal
speed|Moving speed along the shortest path
step|Steps taken in the shortest path
shop|The place that the agent decides to shop at.
times|Times of consuming in one commuting.

Action|Explanation
-|-
move-to-goal|Agents move towards their own independent goal
consume-on-road|While they are travelling, they will consume depend on the factors.
consume-at-goal|When they reach destination, they may consume depend on the factors.

### Patch
Property|Explanation
-|-
landuse|The current land use : Commercial land, Industrial land, Green land
fatherlanduse|The origninal land use when the map was imported.
open|Consumption factor(relate to lasting and cluster), which will decide the amount of money agents give
lasting|The time that the shop has been living
cluster|Degree of commercial aggregation
close|Death factor(relate to earning and rentalsum)
earningsum|The cumulative earning of the land
earning|The cumulative earning of the shop
rentalsum|The cumulative rental of the shop
rental|Rental for the current month(relate to cluster)
rentaltotal|The cumulative rental of the land
chose|Be selected as the recommended commercial land
net|earningsum-rentaltotal

Action|Explanation
-|-
calculate|Calculate the mutual influence of cluster, lasting, rental
Birth-or-death|If net>0, the shop survive. Else, the land has to restart the process.

###  Adjustable variable
Name|Explanation
-|-
ratio|The ratio of formal and informal shop
weight-distance|The influnce of distance on consumption
weight-lasting|The influnce of lasting on open
weight-cluster|The influnce of cluster on open
moneyy|The initial money owned by persons

### Indicators
Name|Explanation
-|-
earnings|The earning of survived shops
rentaltotals|The rental of survived shops
ranking|The rank of net



## Program
The process of program operation is as follows: import road network of the planned area and land use (in shapefile) to show the original commercial scope, in order to make a comparison with the later result, and then clicks the clean button to remove the original business to avoid affecting the simulation. After adjusting the weight of each influencing factor, the agents start to run the program, and the flow of agents is generated every 6 seconds, and the commuting purpose, consumption times and consumption amount are set according to the proportion. At the same time, the stores site selection also changes with the flow of agents. After the model reaches a stable converge, click the left button to output the location of the store with the highest profit and rent of the first 30% by color level, so as to intuitively feel which location is more suitable for the commercial under the influence of specified factors.

Video Introduction in Chinese: https://www.bilibili.com/video/av40330606.
I don't share shapefile for security reason. But if you use this model, please make sure you have layers in landuse shapefile and clean road network shapefile.
