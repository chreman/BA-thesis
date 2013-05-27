;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; To implement:
; different household agents (income groups, demand behaviour, decision making)
; dynamic demand (demand curves)
; price calculation
; refine rainfall model ( l / m³ )
; add supply via rivers and calculate outtake to satisfy demand
; aggregate behaviour (catchments vs. irrigations | rivers vs. urban demand)
; adaptive decision making
;________________________________________________________________________________


;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; Don't forget to load the necessary extensions!
;________________________________________________________________________________

extensions[gis]



;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; Create global variables - check which are really necessary and which can be
; localized!
;________________________________________________________________________________

globals[
  ebro-basin
  rivers-shape
  ebro-discharge-list
  ebro-discharge
  catchments-area
  catchments-centroids
  catchments-list
  irrigation-area
  irrigation-centroids
  irrigation-list
  metric-patch-size
  canals
  cities
  popcores
  week
  year
  rain-list
  precipitation-list
  rain-probability
  irrigated
  water-total
  urban-demand
  price
  price-list
  ]

;turtles-own
;[]

patches-own[
  rain?
  water
  counter
  irrigation-demand?
  catchment-id
  irrigation-id
  ]

breed[irrigations]
breed[households]
breed[water-utilities water-utility]
breed[catchments]
breed[rivers]


irrigations-own[
  centroids 
  area
  productivity
  demand
  id
  ]

households-own[
  population
  income
  demand
  costs
  ]

water-utilities-own[
  cash
  supply
  demand
  id
  ]

catchments-own[
  centroids
  id
  ]

rivers-own[
  capacity
  id
  ]



to setup
;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; Setup-procedure:
; set-patch-size is important, it defines how many patches are going to be in the
; model, and how fine the geographic resolution is going to be.
; !!! Careful: Small values (under 10) increase computing time exponentially !!!
;________________________________________________________________________________

  clear-all
  set-patch-size ps
  load-data
  draw-landscape
  calculate-metric-patch-size
  setup-water-utilities
  setup-popcores
  setup-catchments
  setup-irrigations
  rescale
  reset-ticks
  initialize
end



to load-data
;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; This function loads GIS-data that are provided from a certain source and
; possibly preprocessed by a GIS-tool lika QuantumGIS.
; !!! When transfering the model to different users / machines, don't forget to change
; the file paths !!!
;________________________________________________________________________________

  set rivers-shape gis:load-dataset "data/rivers.shp"
  set irrigation-area gis:load-dataset "data/irrigation.shp"
  set irrigation-centroids gis:load-dataset "data/irrigation-centroids.shp"
  set cities gis:load-dataset "data/cities.shp"
  set popcores gis:load-dataset "data/popcore.shp"
  set catchments-area gis:load-dataset "data/catchments.shp"
  set canals gis:load-dataset "data/canals.shp"
end





to draw-landscape
;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; Since the GIS-shapes are not 1:1 patches, there are some transformations 
; necessary.
; resize-world in combination with patch-size influences resolution of the model
; as well as computational needs! Scale down when necessary.
;________________________________________________________________________________

  resize-world -300 / patch-size 300 / patch-size -150 / patch-size 150 / patch-size
  set ebro-basin gis:envelope-of rivers-shape
  gis:set-transformation ebro-basin (list min-pxcor max-pxcor min-pycor max-pycor)
  gis:set-drawing-color 105
  gis:draw rivers-shape 2
  gis:set-drawing-color 25
  gis:draw irrigation-area 1
  gis:draw irrigation-centroids 2
  gis:set-drawing-color red
  gis:draw catchments-area 2
  gis:set-drawing-color cyan
  gis:draw canals 2
  gis:set-drawing-color yellow
  gis:draw cities 2
end




to setup-irrigations
;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; This function takes 
;________________________________________________________________________________

  foreach gis:feature-list-of irrigation-centroids[
  let location gis:location-of (first (first (gis:vertex-lists-of ?)))
  create-irrigations 1[
    set shape "circle"
    set color 25
    set xcor item 0 location
    set ycor item 1 location
    set size 0.5
    set area gis:property-value ? "area"
  ]]
  set irrigated patches gis:intersecting irrigation-area
  set irrigation-list gis:feature-list-of irrigation-area
  foreach irrigation-list[
    let registro gis:property-value ? "registro"
    let contained patches gis:intersecting gis:find-one-feature irrigation-area "registro" word registro ""
    ask contained[
      set irrigation-id gis:property-value ? "registro"
      set pcolor round irrigation-id / round 100
    ]
  ]
end



to setup-popcores
;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; This procedures creates a number of households. Initially, each household
; is the same, but they can be modelled to reflect certain income groups or
; different demand behaviour.
; It gives each household agent the fractional value of the cities population,
; according to how many agents are created.
;________________________________________________________________________________

  foreach gis:feature-list-of popcores[
  let location gis:location-of (first (first (gis:vertex-lists-of ?)))
  create-households 1000[
    set shape "circle"
    set color yellow
    set xcor item 0 location
    set ycor item 1 location
    set size 2
    set population gis:property-value ? "pobla_06" / 1000
  ]]
end

to setup-water-utilities
;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; This procedure creates one water utility, representing a municipal public water
; provider.
;________________________________________________________________________________

  foreach gis:feature-list-of popcores[
    let location gis:location-of (first (first (gis:vertex-lists-of ?)))
    create-water-utilities 1[
      set shape "pentagon"
      set color yellow - 10
      set xcor item 0 location
      set ycor item 1 location
      set size 2
    ]
  ]
end
      

to setup-catchments
  set catchments-list gis:feature-list-of catchments-area
  foreach catchments-list[
    let cueche-id gis:property-value ? "cueche_"
    let contained patches gis:intersecting gis:find-one-feature catchments-area "cueche_" word cueche-id ""
    ask contained[
      set catchment-id gis:property-value ? "cueche_"
      set pcolor round catchment-id + 5
    ]
  ]
end

to calculate-metric-patch-size
  let world-size gis:world-envelope
  let xlen item 1 world-size - item 0 world-size
  let ylen item 3 world-size - item 2 world-size
  set metric-patch-size int (xlen / world-width + ylen / world-height) / 2
end


to initialize
;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; This is used to initalize certain parameters of the model.
; Especially rain-list is important, where the yearly rainfall pattern is put in.
; It is modeled as days per month with rainfall and taken from national weather
; data.
; Rain and precipitation are taken from:
; http://worldweather.wmo.int/083/c01240.htm ( 19.05.2013 )
; Ebro discharge data is taken from:
; http://www.grdc.sr.unh.edu/html/Polygons/P6226400.html ( 19.05.2013)
; and interpolated from m³/s to m³/week.
;________________________________________________________________________________

  set week 0
  set year 0
  set rain-list [7 7 7 7 6 6 6 6 6 6 6 6 7 8 8 8 8 9 9 9 9 7 6 6 6 6 4 4 4 4 4 4 4 4 5 5 5 5 6 7 7 7 7 8 8 8 8 9 9 9 9 8]
  set precipitation-list [22 22 22 22 20 20 20 20 20 20 20 20 27 35 35 35 35 44 44 44 44 37 31 31 31 31 18 18 18 18 17 17 17 17 32 27 27 27 27 30 30 30 30 30 30 30 30 25 23 23 23 23]
  set ebro-discharge-list [578067840 578067840 578067840 578067840 565306560 565306560 565306560 565306560 618770880 618770880 618770880 618770880 496540800 496540800 496540800 496540800 431161920 431161920 431161920 431161920 362124000 293086080 293086080 293086080 293086080 224350560 155615040 155615040 155615040 155615040 106142400 106142400 106142400 106142400 110799360 110799360 110799360 110799360 156159360 201519360 201519360 201519360 201519360 357920640 357920640 357920640 357920640 456563520 555206400 555206400 555206400 555206400] ; m³ / week
  set price 15
  set price-list [0.21 0.503 1.28]
end




;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; HERE THE SETUP-PROCEDURES END, AND THE BEHAVIOUR-MODELLING BEGINS.
;________________________________________________________________________________

to go
  rain
  urban-demand-function
  irrigate
  agro-demand-function
  price-function
  aggregate
  time
  rescale
  tick
end


to time
  set week week + 1
  if (week = 52)[
    set week 0
    set year year + 1
  ]
end


to rescale
  ask irrigations[
    set size demand / 100000
  ]
end




to rain
;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; This function is modeling the random natural water supply, mainly through
; precipitation. It reflects yearly rainfall patterns with certain random factor.
; It can be refined to reflect natural rainfall patterns.
;________________________________________________________________________________

  ask patches[
    rain-probability-function
    ifelse (random-float 1 < rain-probability / 30)[
      set rain? 1
      set pcolor 9.9
      set water item week precipitation-list / item week rain-list ; precipitation in mm
      set water metric-patch-size * metric-patch-size * water ; quantity of water in liters/patch
      set water water / 1000 ; quantity of water / patch in m³, equivalent to 1.000 liters
      ][ 
      set rain? 0
      set water 0
      set pcolor 35]
  ]
end



to rain-probability-function
  set rain-probability item week rain-list
  set rain-probability rain-probability
end



to irrigate
;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; This function sets the irrigation necessity: If rain falls, irrigation is not
; necessary, if it does not fall on a certain patch which is designated for
; irrigation, it sets the patches flag to "Irrigation is necessary".
; It is modelled after the irrigation period.
;________________________________________________________________________________

  ifelse (week >= 12) and (week <= 40)[
    ask irrigated [
      ifelse (rain? = 1)[
        set irrigation-demand? 0
        set pcolor 9.9][
        set irrigation-demand? 1
        set water water - 1
        set pcolor 25]
        ]
    ][
    ask irrigated[
      set irrigation-demand? 0
      ifelse (rain? = 1)[
        set pcolor 9.9][
        set pcolor 35]
    ]
    ]
end



to aggregate
  set ebro-discharge item week ebro-discharge-list + item week ebro-discharge-list * ((random-float 0.5) - 0.25)
  set urban-demand sum [demand] of households
end




to urban-demand-function
;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; This function calculates the urban water demand. In the simple model, demand
; is equal for all household-agents (which represent a fraction of the cities
; population.
; The demand variable is calculated per capita and later aggregated in the
; aggregate-procedure.
; Right now, demand is calculated as income (which is a certain amount of total
; household income allocated to water) divided through price.
; In the final version it should calculate water demand based on price and a
; demand curve representing the price elasticity of water demand.
; change demand function to newer one (Arbues et al. 2010) !
; qit = e β0 + δp (it−2) + xit′ β e uit
; where β 0 is the independent term, δ is the parameter of the price pit −2 and 
; β is the vector of parameters that accompanies the variables vector xit , which
; encompasses income, the number of residents in the household and the 
; availability of a common supply of hot running water; e uit is an error term.
;________________________________________________________________________________

  ask households[
  set demand (random 150 + 150) * 7 * [population] of self / 1000 ; daily consume * 7 days * fraction of pop. in 1000 liters = 1 m³
  ; set demand e ^ ( β0 + δp (it−2) + xit′ β) e ^ (uit)
  ]
end



to agro-demand-function
;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; This function calculates the water demand for agriculture, starting with a 
; simple demand = 1 for each unwatered patch.
; Right now: Some random value to represent demand per m².
; In the final version it should calculate water demand based on a maximizing
; function with different crop types and irrigation types.
;________________________________________________________________________________

  foreach sort-on [irrigation-id] irrigated[
    ask ? [
      if (rain? = 0) and (irrigation-demand? = 1)[
        let tempid [irrigation-id] of self
        ask irrigations with [irrigation-id = tempid][
          set demand demand + metric-patch-size * metric-patch-size / 1000
        ]
      ]
      if (rain? = 1) and (irrigation-demand? = 1)[
        let tempid [irrigation-id] of self
        ask irrigations with [irrigation-id = tempid][
          set demand demand + metric-patch-size * metric-patch-size / 1000 * (item week precipitation-list / item week rain-list - 10)
        ]
      ]
      if (rain? = 1) and (irrigation-demand? = 0)[
        let tempid [irrigation-id] of self
        ask irrigations with [irrigation-id = tempid][
          set demand 0
        ]
      ]
    ]
  ]
end


to price-function
;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; This function calculates the price for households.
; In a more advanced version, price discrimination can be introduced.
; Data taken from 
; http://www.zaragoza.es/contenidos/normativa/ordenanzas-fiscales/2013/OF_24-25-2013.pdf
; ( 21.05.2013)
;________________________________________________________________________________

  ask households[
  if (demand <= 200)[
    set costs demand * item 0 price-list
  ]
  if (demand > 200) and (demand <= 616)[
    set costs demand * item 1 price-list
  ]
  if (demand > 616)[
    set costs demand * item 2 price-list
  ]]
  set price (sum [demand] of irrigations - sum [water] of irrigations) / metric-patch-size / metric-patch-size * 2 + 10 ; this function is not a scientific model! just for demonstration purposes
end
@#$#@#$#@
GRAPHICS-WINDOW
200
291
815
627
60
30
5.0
1
10
1
1
1
0
0
0
1
-60
60
-30
30
0
0
1
ticks
30.0

BUTTON
27
33
100
66
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
112
33
183
66
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

PLOT
190
18
1235
162
demand
week
quantity
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"urband-demand" 1.0 0 -6459832 true "" "plot urban-demand"
"agro-demand" 1.0 0 -955883 true "" "plot sum [demand] of irrigations"
"overall-demand" 1.0 0 -10899396 true "" "plot urban-demand + sum [demand] of irrigations"

MONITOR
1453
345
1510
390
NIL
week
17
1
11

MONITOR
1515
345
1572
390
NIL
year
17
1
11

MONITOR
1436
660
1547
705
NIL
rain-probability
17
1
11

MONITOR
1449
589
1583
634
NIL
count catchments-
17
1
11

MONITOR
24
80
181
125
total quantity of water
sum [water] of patches
17
1
11

MONITOR
90
151
147
196
NIL
price
17
1
11

PLOT
228
162
1119
282
price
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot price"
"pen-1" 1.0 0 -16777216 true "" "plot 0"
"pen-2" 1.0 0 -16777216 true "" "plot 10"
"pen-3" 1.0 0 -16777216 true "" "plot 20"

SLIDER
15
229
187
262
ps
ps
1
10
1
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
NetLogo 5.0.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
