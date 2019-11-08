;Commercial Growth simulation
;Take Pingqiao Town as example
;By Huang Zhuoya , Liu Zichen and Pan Yanhan, CAUP, Tongji Univ, 2018.12
;Special thanks to Wei Zhu
extensions [gis nw]
breed [nodes node]
breed [persons person]
undirected-link-breed [segments segment]
segments-own [
  segtype
  weight
]
persons-own [
  money;市民的钱包余额
  goal;市民出行目的地
  goalnode;市民出行目的地最近道路交叉口node
  alongpoints;最短路径上的节点node
  speed;行走速度
  step;步数
  shop;市民消费地
  times;市民一次出行消费次数
]

patches-own [
  landuse;用地性质
  fatherlanduse;原始用地性质
  open;消费指标，用于确定每次人的消费金额的指标之一
  lasting;开店时长
  cluster;商业聚集程度
  close;关店门槛
  earningsum;地块累计营业额
  earning;店铺累计营业额
  rental;本月租金
  rentalsum;累计缴纳租金
  chose;是否有选中，用于output
  minnode;存下离每个patch最近的node
  rentaltotal;累计历史缴纳租金
  net;净收入
  outputyet;是否output过，用于output
]

globals [
  DS_Block
  DS_Road
  DS_Center
  DS_Raster
  a1;离person生成位置最近的node坐标
  b1
  a2;goal最近node坐标
  b2
  alongpointsnow;离人生成位置最近的node到离goal最近的node的路线上的node
  benefit;每人单次消费金额
  moneyy;用于存放人钱包money的全局变量
]

to setup
  ca
  reset-ticks
  ask patches [
    set pcolor white
    set chose false ]
  set-current-directory "C:\\Users\\liuzi\\Desktop\\城市模拟作业\\商业增长\\地图"
  set DS_Block gis:load-dataset "pqzydxz.shp"
  set DS_Road gis:load-dataset "pqzroad.shp"
  set DS_Center gis:load-dataset "pqzresi.shp"
  let enve_gis gis:envelope-union-of (gis:envelope-of  DS_Road)(gis:envelope-of DS_Block);;定义坐标转换
  let enve_world (list (min-pxcor + 1) (max-pxcor - 1) (min-pycor + 1) (max-pycor - 1));;定义世界范围
  gis:set-transformation enve_gis enve_world
  build-road
  build-block
  ask patches [
    set minnode min-one-of nodes [ distance myself]]
 end

to build-road
let node_prev nobody
  let location []
  let existed_node nobody
  let node_now nobody
  let distance_now 0
 foreach gis:feature-list-of DS_Road [[ft] ->
    foreach gis:vertex-lists-of ft [[vtl] ->
      set node_prev nobody
      foreach vtl [[vt] ->
        set location gis:location-of vt
        set existed_node one-of nodes with [(xcor = item 0 location and ycor = item 1 location) ]
        ifelse existed_node != nobody
          [set node_now existed_node]
          [create-nodes 1 [
              set shape "circle"
              set size 0.1
              set xcor item 0 location
              set ycor item 1 location
              set color black
              set node_now self]
          ]
        if node_prev != nobody [
          ask node_now [
            create-segment-with node_prev [
            set color black
            set weight gis:property-value ft "weight" ;在gis里面设置了不同的weight，交通性干道的weight是长度的8倍，我们规划希望的生活性发展轴的weight是长度的0.5倍，其他道路的weight就等于长度。
            ]]]
        set node_prev node_now
      ]]]
end

to build-block
  gis:apply-coverage DS_Block "LAYER" landuse
  ask patches [
    if landuse = "industry" [set pcolor brown]
    if landuse = "residential" [set pcolor yellow]
    if landuse = "commercial" [set pcolor red set lasting weight-oldcommercial];原来的店的lasting会比其他店有先天优势，这个优势的权重可以通过滑块调节
    if landuse = "facility" [set pcolor blue]
    if landuse = "park" [set pcolor green]
    set fatherlanduse landuse
    if pcolor = 9.9 [set fatherlanduse "standby" ];standby为备用地
  ]
end

to cleancommercial
  ask patches with [landuse = "commercial" ]
  [   set fatherlanduse "standby";把现有的商业清零一下从头开始模拟。
      set pcolor white]
end

to go
  tick
  breed-people
  move-to-goal
  consume-on-road
  calculate
  birh-or-death
end

 to breed-people
  if ticks mod 10 = 0 [;10次生成一波人，本procedure计算量较大，也就每10次卡一次
  ask patches with [landuse = "residential" ] [
    if  random 100 = 1 [;黄色居住地块里随机百分之一的几率生成人
      sprout-persons 1 [
        set shape "person"
        set color blue
        set size 3
        set speed 5
        move-to minnode;移动到离生成patch最近的node
        set goal nobody
        set step 0
        set alongpoints nobody
        set a1 [xcor] of self
        set b1 [ycor] of self
          let t random 100;接下来要给
          if 0 <= t and t <= 40    [set goal one-of patches with [ landuse = "industry"] set times 6 set money 100];设有40%的人选择去工厂（通勤），去工厂的路上，认为有1/6的可能性会消费，且钱包钱很少
          if 40 < t and t <= 60    [set goal one-of patches with [ landuse = "facility"] set times 2 set money 300];设有20%的人选择去设施（通勤/办事），在去设施的路上，认为有1/2的可能性会消费；钱包300块钱
          if 60 < t and t <= 80 [ set goal one-of patches with [ landuse = "park"] set times 3 set money 200 ];设有20%的人选择去公园（休闲），在去公园的路上，认为有1/3的可能性会消费；钱包200块钱
          if 80 < t [ set goal one-of patches with [ landuse = "commercial"] set times 1 set money 600];设有20%的人选择去商业（消费），在去商业的路上，认为百分之百会消费，钱包很鼓
          set goalnode [minnode] of goal;离goal最近的node作为goalnode
        set a2 [xcor] of goalnode
        set b2 [ycor] of goalnode
    ifelse  a1 = a2 and b1 = b2  [die] [;防止出发地和目的地在用一个地方
    ask one-of nodes with [xcor = a1  and ycor = b1] [
      set alongpointsnow nw:turtles-on-weighted-path-to one-of nodes with [xcor = a2 and ycor = b2]  weight];离人生成位置最近的node到离goal最近的node的路线上
      set alongpoints alongpointsnow
      set step 1]]
  ]]]
end

to move-to-goal
   ask persons [
    face item step alongpoints
    ifelse distance item step alongpoints <= speed;人走
    [let part_speed distance item step alongpoints
      forward part_speed
      ifelse step = length alongpoints - 1 [
          consume-at-goal;在到达目标的时候，回光返照花一笔大钱
          die]
       [set step step + 1
        face item step alongpoints
        forward (speed - part_speed)]]
    [forward speed]
  ]
end

to consume-at-goal
   set shop one-of (patches  in-radius 3)
   set moneyy money
   let dis distance shop
   ask shop [
      set benefit  open * 1.5 * ratio  + 1.5 * ratio * weight-distance / dis ;回光返照花的钱是在商铺单笔消费的1.5倍
   if moneyy < benefit [set benefit moneyy ]
      set earning earning + benefit;商铺的累计营业额
      set earningsum earningsum + benefit] ;地块历史累计营业额
   set money money - benefit;人的钱包余额
end

to consume-on-road
  ask persons [
    if random times = 0 and money > 0[
      set shop one-of patches  in-radius 3;随机选择与人距离为3的patch作为消费对象
      let dis distance shop
      ask shop [
        ifelse  landuse = "commercial";判断是地摊还是商铺
        [set benefit open * ratio + ratio * weight-distance / dis;在商铺的单笔消费是地摊的ratio倍
         set earning earning + benefit
         set earningsum earningsum + benefit ]
        [set benefit open + weight-distance / dis;在地铺（没有形成商业的任何一个patch）的单笔消费的价格由open（也就是lasting和cluster）以及与人的距离（乘权重）决定
         set earning earning + benefit;累计营业额
         set earningsum earningsum + benefit ]];累计历史营业额
      set money money - benefit;人的钱包余额减去消费
  ]
  ]
end

to calculate
  ask patches with [ landuse = "commercial" ]
  [set lasting lasting + 1
  ask neighbors [set lasting lasting + 0.05]]
  if ticks mod 6 = 0 [
  ask patches
  [let potential sum [earningsum] of neighbors / 20
   let potential2 count neighbors with [landuse = "commercial"]
   set cluster potential / ticks + potential2 ;数一数周边有几个商业以及周边商业的经济价值，来决定商业集聚效应
   set rental 3 + cluster * 0.5  + lasting  / ticks + earningsum * 0.2 / ticks  ;租金与集聚程度、商业历史价值、现有商业经济价值有关
   set rentalsum rentalsum + rental;累计缴纳租金rentalsum（相当于每六次收一次月租rental）
   set rentaltotal rentaltotal + rental
   set open lasting / ticks * weight-lasting + cluster * weight-cluster;lasting/tick为这个地段的历史商业价值标准化，cluster为集聚程度，weight为各指标的权重
  ]]
end

to birh-or-death
   if ticks mod 6 = 0 [
  ask patches
  [if earning > rental  [birth];营业额大于租金，开店
   if landuse =  "commercial" and ticks > 20 [;tick大于20是为了在第一遍的人生成走完一遍之后再进行关店运算
   set close earning - rentalsum;营业额小于租金，关店
   if  close < 0 [death]]
  ]]
end

to birth
  set landuse  "commercial"
  set pcolor red
end

to death
  set landuse  fatherlanduse
  if fatherlanduse = "industry" [set pcolor brown];当关店之后，回到原来的landuse
  if fatherlanduse = "residential" [set pcolor yellow]
  if fatherlanduse = "facility" [set pcolor pink]
  if fatherlanduse = "park" [set pcolor green]
  if fatherlanduse = "commercial" [set landuse "residential" set pcolor yellow]
  if fatherlanduse = "standby" [set landuse "standby" set pcolor white]
  set rentalsum 0
  set earning 0
end

to outputearning
  ask persons [die]
  ask patches with [ landuse ="commercial" or chose = true ][set pcolor white set chose false]
  let n count patches with [lasting > 0];数一数能够有潜力成为商业的嵌块数
  let m n * 0.3
  ask max-n-of m patches with [lasting > 0] [earningsum][;有潜力成为商业的历史累计营业额的前30%，为推荐商业选址
    set chose true
    set pcolor  red + 5]
  let earnings [earningsum] of patches with [chose = true];把累计历史营业额放入一个集合，并将营业额大小反映在颜色上
  ask patches with [chose = true][set pcolor scale-color red earningsum max earnings min earnings
  ]
end

to outputrental
  ask persons [die]
  ask patches with [ landuse ="commercial" or chose = true][set pcolor white set chose false]
  let n count patches with [lasting > 0];数一数能够有潜力成为商业的嵌块数
  let m n * 0.3
  ask max-n-of m patches with [lasting > 0] [rentaltotal][;有潜力成为商业的历史累计营业额的前30%，为推荐商业选址
    set chose true
    set pcolor  red]
  let rentaltotals [rentaltotal] of patches with [chose = true];把累计历史租金放入一个集合，并将营业额大小反映在颜色上
  ask patches with [chose = true][set pcolor scale-color blue rentaltotal max rentaltotals min rentaltotals
  ]
end

to outputnetearning
  ask persons [die]
  ask patches with [ landuse ="commercial" or chose = true][set pcolor white set chose false]
  ask patches [
    set net earningsum - rentaltotal
    if net > 0
    [set pcolor orange ];历史累计净赚大于零的位置，这是不太可能赔钱的地方
  ]
end

to outputranking
  clear-output
  let j 1
  outputnetearning
  ask patches [ set outputyet false]
  output-type " label\tnet\n"
  while [any? patches with [outputyet = false ] and j < 11];把排名前10的黄金地块挨个揪出来排队
  [ask max-one-of patches with [outputyet = false ][net]
    [set plabel j
     set plabel-color black
     set pcolor red
     set outputyet true
     output-type j
     output-type "\t"
     output-type precision net 2
     output-type "\n"]
   set j j + 1]
end
@#$#@#$#@
GRAPHICS-WINDOW
268
10
925
668
-1
-1
3.23
1
10
1
1
1
0
0
0
1
-100
100
-100
100
0
0
1
ticks
30.0

BUTTON
39
10
106
43
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
37
294
231
361
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
38
200
232
233
weight-distance
weight-distance
0
100
81.0
1
1
NIL
HORIZONTAL

SLIDER
37
104
235
137
weight-lasting
weight-lasting
0
30
27.0
1
1
NIL
HORIZONTAL

SLIDER
37
154
233
187
weight-cluster
weight-cluster
0
10
8.0
1
1
NIL
HORIZONTAL

SLIDER
38
245
233
278
ratio
ratio
0
5
4.0
1
1
NIL
HORIZONTAL

BUTTON
119
10
235
43
NIL
cleancommercial
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
956
295
1079
328
NIL
outputearning\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1108
294
1230
327
NIL
outputrental
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
956
345
1079
378
NIL
outputnetearning
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

OUTPUT
955
410
1230
667
13

BUTTON
1108
345
1229
378
NIL
outputranking
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
38
60
236
93
weight-oldcommercial
weight-oldcommercial
0
300
273.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
