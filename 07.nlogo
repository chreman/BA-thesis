;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; To implement:
; different household agents (income groups, demand behaviour, decision making)
; dynamic demand (demand curves)
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
  ; for landscaping
  ebro-basin
  rivers-shape
  catchments-area
  catchment-centroids
  irrigation-area
  irrigation-centroids
  canals
  cities
  popcores
  ; for environmental simulation
  week
  year
  world-extent
  metric-patch-size
  temperature-list
  temperature
  ebro-discharge-list-mean
  ebro-discharge-list-min
  ebro-discharge-list-max
  ebro-discharge
  drought?
  ; for agent behaviour
  availiable-water
  scarcity
  storage
  storage-limit
  HD
  irrigated
  price-list
  price-factors
  crop-list
  crop-demand-list
  crop-productivity-list
  counter
  ; for monitoring
  water-total
  urban-demand
  urban-demand-acc
  agro-demand-total
  agro-demand-acc
  price
  economic-value
  ]

;turtles-own
;[]

patches-own[
  rain?
  water
  irrigation-demand?
  catchment-id
  irrigation-id
  ]

breed[irrigations irrigation]
breed[households household]
breed[water-utilities water-utility]
breed[catchments catchment]
breed[rivers river]


irrigations-own[
  id
  centroids
  area
  area-type ; 0 for small, 1 for large
  crop-type
  crop-demand
  crop-productivity
  irrigation-type ; 0 for surface, 1 for pressurized
  demand
  utility
  utility-loss
  scarcity-share
  scarcity-demand
  scarcity-utility
  costs
  drought-memory
  ]

households-own[
  population
  income
  demand
  demand-acc
  demand-pc
  demand-agg
  costs
  cost-history
  D1
  D2
  D3
  D4
  hh-size
  W
  CHW
  AG20
  AG60
  utility
  utility-loss
  scarcity-share
  scarcity-demand
  scarcity-utility
  tech-factor ; 0 for low, 0.1 for high efficiency
  ]

water-utilities-own[
  cash
  demand
  id
  ]

catchments-own[
  id
  centroids
  area
  level
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
; !!! Careful: Small values (under 5) increase computing time exponentially !!!
;________________________________________________________________________________

  clear-all
  set-patch-size 4
  set world-extent 360
  initialize
  load-data
  draw-landscape
  calculate-metric-patch-size
  setup-households
  setup-water-utilities
  setup-catchments
  setup-agriculture
  reset-ticks
end



to load-data
;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; This function loads GIS-data that are provided from a certain source and
; possibly preprocessed by a GIS-tool lika QuantumGIS.
; They should be included with the download and be placed in the same folder as
; the .nlogo file.
;________________________________________________________________________________

  set rivers-shape gis:load-dataset "data2/rivers.shp"
  set irrigation-area gis:load-dataset "data2/irrigations.shp"
  set irrigation-centroids gis:load-dataset "data2/irrigation-centroids.shp"
  set cities gis:load-dataset "data2/cities.shp"
  set popcores gis:load-dataset "data2/popcores.shp"
  set catchments-area gis:load-dataset "data2/catchments.shp"
  set catchment-centroids gis:load-dataset "data2/catchment-centroids.shp"
; set canals gis:load-dataset "data2/canals.shp"
end





to draw-landscape
;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; Since the GIS-shapes are not 1:1 patches, there are some transformations
; necessary.
; resize-world in combination with patch-size influences resolution of the model
; as well as computational needs! Scale down when necessary.
;________________________________________________________________________________

  resize-world -1 * (world-extent / patch-size) (world-extent / patch-size) -1 * (world-extent / 2 / patch-size) (world-extent / 2 / patch-size)
  set ebro-basin gis:envelope-of catchments-area
  gis:set-transformation ebro-basin (list min-pxcor max-pxcor min-pycor max-pycor)
  gis:set-drawing-color 105
  gis:draw rivers-shape 1
  gis:set-drawing-color 25
  gis:draw irrigation-area 1
  gis:draw irrigation-centroids 2
  gis:set-drawing-color red
  gis:draw catchments-area 2
  gis:set-drawing-color cyan
; gis:draw canals 2
  gis:set-drawing-color yellow
  gis:draw cities 2
end




to setup-agriculture
;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; This function takes the feature list of irrigated areas from the GIS-data
; and creates one agent representing one irrigated area.
;________________________________________________________________________________

  foreach gis:feature-list-of irrigation-centroids[
  let location gis:location-of (first (first (gis:vertex-lists-of ?)))
  create-irrigations 1[
    set shape "circle"
    set color 25
    set xcor item 0 location
    set ycor item 1 location
    set size 0.5
    set irrigation-type 0
    set crop-type 0
    set area gis:property-value ? "area" / 10000 ; transform to ha (100x100 m)
    let cropr random length crop-list
    set crop-type item cropr crop-list
    set crop-demand item cropr crop-demand-list
    set crop-productivity item cropr crop-productivity-list
    let typer random 2
    set drought-memory 0
    if (typer = 1)[set irrigation-type 1]
  ]]
  set irrigated patches gis:intersecting irrigation-area
  let irrigation-list gis:feature-list-of irrigation-area
  ; the next procedure links the irrigation-areas with the irrigation-agents
  foreach irrigation-list[
    let registro gis:property-value ? "registro"
    let contained patches gis:intersecting gis:find-one-feature irrigation-area "registro" word registro ""
    ask contained[
      set irrigation-id gis:property-value ? "registro"
      set pcolor round (62 + irrigation-id / 4500)
    ]
  ]
end



to setup-households
;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; This procedures creates a number of households. Initially, each household
; is the same, but they can be modelled to reflect certain income groups or
; different demand behaviour.
; It gives each household agent the fractional value of the cities population,
; according to how many agents are created.
;________________________________________________________________________________

  foreach gis:feature-list-of popcores[
  let location gis:location-of (first (first (gis:vertex-lists-of ?)))
  create-households 100[
    set shape "circle"
    set color yellow
    set xcor item 0 location
    set ycor item 1 location
    set size 1
    set population gis:property-value ? "pobla_06" / 1000
    set D1 0
    set D2 0
    set D3 0
    set D4 0
    set AG20 0
    set AG60 0
    let hogares (random-float 1) * 100
    if (hogares >= 00.00) and (hogares < 11.61)[
      set D1 1
      set hh-size 1]
    if (hogares >= 11.61) and (hogares < 45.55)[
      set D2 1
      set hh-size 2]
    if (hogares >= 45.55) and (hogares < 70.88)[
      set D3 1
      set hh-size 3]
    if (hogares >= 70.88) and (hogares <= 100)[
      set D4 1
      set hh-size 4]
    set W random-normal 25874 16421
    while [W < 5000] [set W random-normal 27874 16421]
    let CHWr random-float 1
    if (CHWr > 0.5) [set CHW 1]
    let AGr random-float 1 * 100
    if (AGr < 12.19) [set AG20 1]
    if (AGr > 62.8) [set AG60 1]
    set cost-history [80 70 80 90]
    set demand hh-size * 100 * 7 / 1000
    let techr random-float 1
    ifelse (techr > 0.8)[
    set tech-factor 1.1][
    set tech-factor 1.0]
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
      set size 4
    ]
  ]
end



to setup-catchments
  let catchments-list gis:feature-list-of catchments-area
  foreach catchments-list[
    let cueche-id gis:property-value ? "cueche_"
    let contained patches gis:intersecting gis:find-one-feature catchments-area "cueche_" word cueche-id ""
    ask contained[
      set catchment-id gis:property-value ? "cueche_"
      set pcolor 35
    ]
  ]
  foreach gis:feature-list-of catchment-centroids[
  let location gis:location-of (first (first (gis:vertex-lists-of ?)))
  create-catchments 1[
    set shape "circle"
    set color blue
    set xcor item 0 location
    set ycor item 1 location
    set size 1
    set id gis:property-value ? "cueche_"
    set area gis:property-value ? "area"
    set level gis:property-value ? "level"
  ]]
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
;
; Rain, precipitation and temperature are taken from:
; http://worldweather.wmo.int/083/c01240.htm ( 19.05.2013 )
; Ebro discharge data is taken from:
; http://www.grdc.sr.unh.edu/html/Polygons/P6226800.html ( 19.05.2013)
; and interpolated from m³/s to m³/week.
;________________________________________________________________________________

  set week 0
  set year 0
  set storage random 6000
  set storage-limit 6837
  set temperature-list [6.35 6.35 6.35 6.35 8.4 8.4 8.4 8.4 10.9 10.9 10.9 10.9 10.9 13.1 13.1 13.1 13.1 13.1 17.2 17.2 17.2 17.2 17.2 21.25 21.25 21.25 21.25 24.6 24.6 24.6 24.6 24.4 24.4 24.4 20.7 20.7 20.7 20.7 20.7 15.5 15.5 15.5 15.5 10.1 10.1 10.1 10.1 7. 7. 7. 7. 7.]
  set ebro-discharge-list-mean [370 370 370 385 400 416 416 430 430 447 447 420 399 398 397 380 367 357 347 337 318 308 298 288 279 268 180 148 139 128 108 99 89 91 92 95 97 110 120 119 168 183 193 220 240 292 310 328 338 340 348 358]
  set ebro-discharge-list-min [80 88 88 88 88 75 75 75 75 65 57 57 57 57 65 65 45 35 35 26 26 37 48 53 40 35 30 25 12 12 14 14 18 22 28 30 30 30 30 28 28 28 32 35 40 44 49 55 66 66 77 77]
  set ebro-discharge-list-max[1199 1199 1199 1199 1140 1089 1089 1289 1289 1495 1495 1495 1300 1200 1100 1050 974 974 1100 1297 1297 1297 1250 1090 996 890 830 790 690 562 462 369 340 320 279 289 295 310 340 395 440 495 540 595 695 758 759 801 850 901 1150 1313]
  ; all discharges measured in Hm³ = mio m³ per week
  set price 2
  set price-list [0.210 0.503 1.258]
; β0 δ1 δ2 δ3 δ4 δ5 δ6 δ7 β1 β2 β3 β4
  set price-factors [-0.7026 -0.2645 -1.0525 -0.9509 -0.1983 -0.0078 -0.0409 0.3228 0.000002941 -0.1087 0.0684 -0.0692]
; set crop-list ["corn" "alfalfa" "olives" "tomatoes"]
  set crop-list [0 1 2 3]
  set crop-demand-list [288 353 115 216] ; water demand m³/hectar per week
  set crop-productivity-list [0.13 0.83 0.42 1.0] ; € / m³
end




;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
;
; HERE THE SETUP-PROCEDURES END, AND THE BEHAVIOUR-MODELLING BEGINS.
;
;________________________________________________________________________________

to go
  environment
  household-demand-function
  agriculture-demand-function
  aggregate
  supply
  if (hh-learning?) [hh-learn]
  if (hh-tech-improve?) [hh-tech-improve]
  if (agro-learn?) [agro-learn]
  if (agro-tech-improve?) [agro-tech-improve]
  time
  tick
end



to time
  set week week + 1
  if (week = 52)[
    set week 0
    set year year + 1
    ifelse (random-float 1 > drought-possibility)[set drought? FALSE][set drought? TRUE]
  ]
end



to environment
;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; This function is modeling the random natural water supply, mainly through
; precipitation. It reflects yearly rainfall patterns with certain random factor.
; It can be refined to reflect natural rainfall patterns.
;________________________________________________________________________________

  set ebro-discharge item week ebro-discharge-list-mean + item week ebro-discharge-list-mean * ((random-float 0.4) - 0.2) ; Hm³ = mio m³
  if drought? = TRUE [set ebro-discharge ebro-discharge * ((random-float 0.1) + 0.5)]
  let t1 item week temperature-list
  let t2 item week temperature-list / 4
  set temperature random-normal t1 t2
  ifelse (temperature >= 18) [
    set HD 1][
    set HD 0]
end


to aggregate
  set urban-demand-acc urban-demand-acc + sum [demand-agg] of households / 1000000; Hm³
  set agro-demand-acc agro-demand-acc + sum [demand] of irrigations / 1000000 ; Hm³
  set urban-demand (mean [demand-pc] of households * sum [population] of households) / 1000000; m³
  set agro-demand-total sum [demand] of irrigations / 1000000 ; m³
  set price sum [costs] of households / sum [demand] of households / 7 ; this function is not a scientific model! just for demonstration purposes
  set economic-value urban-demand * price
  if (week = 51)[set urban-demand-acc 0 set agro-demand-acc 0]
end


to supply
  set availiable-water ebro-discharge - minimum-flow * 3600 * 24 * 7 / 1000000; Hm³ / week <=> 350m³ / s
  if (availiable-water > 0) and (storage <= storage-limit)[
    let fill storage-limit - storage
    ifelse (availiable-water <= fill) [
      set storage storage + availiable-water; max 6837 Hm³
      set availiable-water 0][
      set storage storage + fill
      set availiable-water availiable-water - fill]]
  if (availiable-water < 0) and (storage > 0)[
    set storage storage + availiable-water
    set availiable-water 0]
  set storage storage - urban-demand - agro-demand-total
  if year = 10 and week = 2 [set storage-limit storage-limit * storage-expansion-factor]
  ifelse (storage < 0 and availiable-water < 0) [set scarcity availiable-water * (-1000000)][set scarcity 0] ;  m³
end



to household-demand-function
;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; This function calculates the urban water demand. In the simple model, demand
; is equal for all household-agents (which represent a fraction of the cities
; population).
; In this more improved version, the demand is calculated per household and
; later aggregated in the aggregate-procedure.
;
; Demand function according to Arbues et al. 2010.
; qit = e ^ ( β0 + δ1 * deit-2 + δ2 * D1 * deit-2 + δ3 * D2 * deit-2 + δ4 * D3 * deit-2 + δ5 * D4 * deit-2 +
; δ6 * HD + δ7 ln deit-4 + β1 * W + β2 * CHW + β3 * AG20 + β4 * AG60 * u)
;
; This function then calculates the costs for households.
; In a more advanced version, price discrimination can be introduced.
; Data taken from
; http://www.zaragoza.es/contenidos/normativa/ordenanzas-fiscales/2013/OF_24-25-2013.pdf
; ( 21.05.2013)
;________________________________________________________________________________

  ask households[
  let deit-2 item 1 cost-history
  let deit-4 item 3 cost-history
  if (deit-2 < 1)[set deit-2 (item 0 cost-history + item 2 cost-history) / 2 ]
  if (deit-4 < 1)[set deit-4 mean cost-history]
  set demand e ^ (
    item 0 price-factors +
    item 1 price-factors * deit-2 +
    item 2 price-factors * D1 * deit-2 +
    item 3 price-factors * D2 * deit-2 +
    item 4 price-factors * D3 * deit-2 +
    item 5 price-factors * D4 * deit-2 +
    item 6 price-factors * HD +
    item 7 price-factors * (ln deit-4) +
    item 8 price-factors * W +
    item 9 price-factors * CHW +
    item 10 price-factors * AG20 +
    item 11 price-factors * AG60 +
    (random-float 0.5) - 0.25)
  set demand demand * 7 / tech-factor; m³ / week
  set demand-pc demand / hh-size ; m³ / week
  set demand-acc demand-acc + demand ; m³
  set demand-agg demand-pc * population ; m³
  if (counter = 13)[
    if (demand-acc / 13 / 7 <= 0.200)[
      set costs demand-acc * item 0 price-list]
    if (demand-acc / 13 / 7 > 0.200) and (demand-acc / 13 / 7 <= 0.616)[
      set costs demand-acc * item 1 price-list]
    if (demand-acc / 13 / 7 > 0.616)[
      set costs demand-acc * item 2 price-list]
  set costs costs + costs * cost-dynamics * year
  set cost-history replace-item 3 cost-history item 2 cost-history
  set cost-history replace-item 2 cost-history item 1 cost-history
  set cost-history replace-item 1 cost-history item 0 cost-history
  set cost-history replace-item 0 cost-history costs
  set counter 0
  set demand-acc 0]
  set counter counter + 1
  set utility demand-pc * hh-size * tech-factor * tech-factor * price ; m³ * € / m³ = €
  set utility-loss 0]
  if scarcity > 0 [ask households [
  set scarcity-share scarcity * scarcity-distribution / sum [population] of households * hh-size ; m³
  set scarcity-demand demand - scarcity-share
  if scarcity-demand < (0.05 * hh-size) [set scarcity-demand 0.05 * hh-size]
  set scarcity-utility scarcity-demand * tech-factor * tech-factor * price; m³ * € / m³ = €
  set utility-loss utility - scarcity-utility ; m³
  ]]
end


to agriculture-demand-function
;°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
; This function calculates the water demand for agriculture, starting with a
; simple demand = 1 for each unwatered patch.
; Right now: Some random value to represent demand per m².
; In the final version it should calculate water demand based on a maximizing
; function with different crop types and irrigation types.
;________________________________________________________________________________

  ifelse (week > 12) and (week <= 40)[
    ask irrigated[
      set irrigation-demand? 1
      set pcolor round (62 + irrigation-id / 4500)]][
    ask irrigated[
      set irrigation-demand? 0
      set pcolor 35]
      ]
   ask irrigations[
     set demand crop-demand * area * irrigation-demand? ; m³/10.000 m² * m ² = m³
     set costs demand * crop-productivity * 0.5
     set utility crop-productivity / crop-demand * crop-demand * area; €/m³ * m³ / ha * ha = €
     set utility-loss 0]
   if scarcity > 0 [ ask irrigations[
     set scarcity-share scarcity * ( 1 - scarcity-distribution) / sum [area] of irrigations; ; m³ / ha
     set scarcity-utility crop-productivity / crop-demand * (crop-demand - scarcity-share) * area ; € / m³ * m³ / ha * ha = €
     set utility-loss utility - scarcity-utility
   ]]
end

to hh-tech-improve
  if week mod 12 = 4 and year > 2[
  ask n-of 300 households[
    let own-utility utility
    let own-costs mean cost-history
    let peers households with [costs < own-costs]
    set peers peers with [utility > own-utility]
    if any? peers[
      let peers-tech mean [tech-factor] of peers
      if (peers-tech > 1.05)[
        set tech-factor 1.1]
    ]]
  ]
end

to hh-learn
  if week mod 12 = 4 and year > 2[
  ask n-of 36 households[
    let own-utility utility
    let own-costs mean cost-history
    let peers households with [costs < own-costs]
    set peers peers with [utility > own-utility]
    if any? peers[
      let peers-size round mean [hh-size] of peers
      if (peers-size - hh-size <= 1)[
      set hh-size peers-size]
    ]
  ]
  ]
end

to agro-learn
  if (week = 10)[ ask irrigations[
      ifelse (drought? = TRUE)[
        set drought-memory drought-memory + 1][
        set drought-memory drought-memory - 1]
      if (drought-memory < 1) [set drought-memory 0]
      if (drought-memory > 5) [set drought-memory 5]
  ]]
  if (week = 11)[
    ask n-of 36 irrigations[
      let strategies [0 0 0 0]
      set strategies replace-item 0 strategies (item 0 crop-productivity-list / item 0 crop-demand-list * (1 - drought-memory) ^ 5)
      set strategies replace-item 1 strategies (item 1 crop-productivity-list / item 1 crop-demand-list * (1 - drought-memory) ^ 5)
      set strategies replace-item 2 strategies (item 2 crop-productivity-list / item 2 crop-demand-list * (1 - drought-memory) ^ 5)
      set strategies replace-item 3 strategies (item 3 crop-productivity-list / item 3 crop-demand-list * (1 - drought-memory) ^ 5)
      let max-value max strategies
      let index position max-value strategies
      set crop-type item index crop-list
      set crop-demand item index crop-demand-list
      set crop-productivity item index crop-productivity-list
    ]]
end

to agro-tech-improve  if (week = 10)[
    ask n-of 36 irrigations[
      set irrigation-type 1
  ]]
end
@#$#@#$#@
GRAPHICS-WINDOW
1
150
735
545
90
45
4.0
1
10
1
1
1
0
0
0
1
-90
90
-45
45
0
0
1
ticks
30.0

BUTTON
9
10
82
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
182
10
253
43
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
3
550
676
807
supply & demand
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
"urban demand" 1.0 0 -4079321 true "" "plot urban-demand"
"overall demand" 1.0 0 -2674135 true "" "plot urban-demand + agro-demand-total"
"agric. demand" 1.0 0 -13840069 true "" "plot agro-demand-total"
"availiable water" 1.0 0 -13345367 true "" "plot availiable-water"
"ebro minimum flow" 1.0 0 -16777216 true "" "plot minimum-flow * 3600 * 24 * 7 / 1000000"
"ebro discharge" 1.0 0 -11221820 true "" "plot ebro-discharge"
"storage" 1.0 0 -16449023 true "" ";plot storage"
"pen-7" 1.0 0 -7500403 true "" "plot scarcity / 1000000"

MONITOR
775
10
832
55
NIL
week
17
1
11

MONITOR
831
10
888
55
NIL
year
17
1
11

MONITOR
1026
104
1135
149
avg. price / m³
price
17
1
11

PLOT
747
389
1157
509
price
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"price" 1.0 0 -2674135 true "" "plot price"

MONITOR
808
58
889
103
population
sum [population] of households
17
1
11

MONITOR
992
10
1135
55
urban demand
sum [demand] of households
17
1
11

PLOT
750
631
1160
751
Temperature
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
"temperature" 1.0 0 -16777216 true "" "plot temperature"
"hot day?" 1.0 1 -7500403 true "" "plot HD"

MONITOR
896
57
1030
102
demand per hh / day
sum [demand] of households / count households / 7
17
1
11

MONITOR
896
104
1024
149
avg. costs / quarter
sum [costs] of households / 1000
17
1
11

MONITOR
896
10
991
55
demand p.c.
sum [demand-pc] of households / sum [hh-size] of households / 7
17
1
11

PLOT
755
149
1155
269
demand p.c. [liters / day]
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
"default" 1.0 0 -16777216 true "" "plot (sum [demand-pc] of households with [demand-pc > 1] / sum [hh-size] of households / 7) * 1000"
"pen-1" 1.0 0 -7500403 true "" "plot (mean [scarcity-demand] of households with [demand-pc > 1] / 7)"

PLOT
1437
10
1597
130
household demand / day
NIL
NIL
0.0
10.0
0.0
50.0
false
false
"" ""
PENS
"default" 0.1 1 -16777216 true "" "histogram [demand / 7] of households with [demand > 1]"

PLOT
1274
10
1434
130
costs
NIL
NIL
0.0
100.0
0.0
30.0
false
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [costs] of households with [costs > 1]"

BUTTON
87
10
177
43
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
1274
131
1434
251
cost-history
NIL
NIL
0.0
100.0
0.0
30.0
false
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [item 0 cost-history] of households with [costs > 1]"
"pen-1" 1.0 1 -7500403 true "" "histogram [item 1 cost-history] of households with [costs > 1]"
"pen-2" 1.0 1 -2674135 true "" "histogram [item 2 cost-history] of households with [costs > 1]"
"pen-3" 1.0 1 -955883 true "" "histogram [item 3 cost-history] of households with [costs > 1]"

PLOT
751
268
1154
388
mean utility of households
NIL
NIL
0.0
10.0
0.0
5.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot (mean [utility] of households with [demand-pc > 1])"
"pen-1" 1.0 0 -7500403 true "" "plot mean [utility-loss] of households with [demand-pc > 1]"

PLOT
760
510
1158
630
irrigation per ha / week
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
"default" 1.0 0 -16777216 true "" "plot sum [demand] of irrigations / sum [area] of irrigations"

PLOT
1437
132
1597
252
demand p.c. / day
NIL
NIL
0.0
10.0
0.0
30.0
false
false
"" ""
PENS
"default" 0.1 1 -16777216 true "" "histogram [demand-pc / 7] of households with [demand > 1]"

PLOT
1228
494
1388
614
irrigation demand
NIL
NIL
0.0
500000.0
0.0
10.0
true
false
"" ""
PENS
"default" 10000.0 1 -16777216 true "" "histogram [demand] of irrigations"

MONITOR
1391
497
1631
542
NIL
mean [demand] of irrigations
17
1
11

PLOT
1227
372
1387
492
area
NIL
NIL
0.0
2000000.0
0.0
10.0
true
false
"" ""
PENS
"default" 50000.0 1 -16777216 true "" "histogram [area] of irrigations"

PLOT
1225
641
1425
791
irrigations
NIL
NIL
0.0
1000.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [crop-demand] of irrigations"

MONITOR
749
753
923
798
NIL
sum [area] of irrigations
17
1
11

PLOT
1437
252
1597
372
hh-utility
NIL
NIL
0.0
100.0
0.0
100.0
false
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [utility] of households with [utility > 1]"

PLOT
1440
642
1640
792
agro-utility
NIL
NIL
0.0
100.0
0.0
10.0
true
false
"" ""
PENS
"default" 0.2 1 -16777216 true "" "histogram [utility] of irrigations with [utility > 1]"

MONITOR
1033
57
1181
102
NIL
agro-demand-total
17
1
11

PLOT
1601
131
1761
251
mean household-size
NIL
NIL
0.0
10.0
0.0
3.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count households with [hh-size = 1]"
"pen-1" 1.0 0 -7500403 true "" "plot count households with [hh-size = 2]"
"pen-2" 1.0 0 -2674135 true "" "plot count households with [hh-size = 3]"
"pen-3" 1.0 0 -13840069 true "" "plot count households with [hh-size >= 4]"

MONITOR
1602
85
1810
130
NIL
mean [hh-size] of households
17
1
11

PLOT
1646
667
1806
787
mean irrigation utility
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
"default" 1.0 0 -16777216 true "" "plot mean [utility] of irrigations"

PLOT
1599
252
1759
372
mean tech-factor
NIL
NIL
0.0
10.0
0.0
2.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [tech-factor] of households"

MONITOR
1599
375
1756
420
NIL
mean [tech-factor] of households
17
1
11

SWITCH
10
46
143
79
hh-learning?
hh-learning?
0
1
-1000

SWITCH
9
81
189
114
hh-tech-improve?
hh-tech-improve?
0
1
-1000

SLIDER
262
10
432
43
drought-possibility
drought-possibility
0.1
0.25
0.25
0.05
1
NIL
HORIZONTAL

SLIDER
553
11
725
44
cost-dynamics
cost-dynamics
0
1
0
0.05
1
NIL
HORIZONTAL

MONITOR
724
94
795
139
NIL
drought?
17
1
11

SLIDER
551
50
723
83
minimum-flow
minimum-flow
150
350
250
50
1
NIL
HORIZONTAL

SWITCH
191
51
330
84
agro-learn?
agro-learn?
0
1
-1000

SWITCH
194
91
389
124
agro-tech-improve?
agro-tech-improve?
0
1
-1000

SLIDER
348
52
540
85
storage-expansion-factor
storage-expansion-factor
1
1.5
1.5
0.25
1
NIL
HORIZONTAL

SLIDER
393
96
591
129
scarcity-distribution
scarcity-distribution
0
1
0.6
0.2
1
NIL
HORIZONTAL

PLOT
1169
220
1369
370
utility losses
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
"default" 1.0 0 -16777216 true "" "plot sum [utility-loss] of households"
"pen-1" 1.0 0 -7500403 true "" "plot sum [utility-loss] of irrigations"

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
NetLogo 5.0.3
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="baselines" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1144"/>
    <metric>round storage</metric>
    <metric>sum [demand-pc / 7 * 1000] of households with [demand-pc &gt; 1] / sum [hh-size] of households</metric>
    <metric>mean [utility] of households with [demand-pc &gt; 1]</metric>
    <metric>sum [utility] of households with [demand-pc &gt; 1]</metric>
    <metric>mean [utility-loss] of households with [demand-pc &gt; 1]</metric>
    <metric>sum [utility-loss] of households with [demand-pc &gt; 1]</metric>
    <metric>mean [utility] of irrigations with [demand &gt; 1]</metric>
    <metric>sum [utility] of irrigations with [demand &gt; 1]</metric>
    <metric>mean [utility-loss] of irrigations with [demand &gt; 1]</metric>
    <metric>sum [utility-loss] of irrigations with [demand &gt; 1]</metric>
    <metric>round ebro-discharge</metric>
    <metric>sum [utility-loss] of households</metric>
    <metric>sum [utility-loss] of irrigations</metric>
    <metric>sum [costs] of households</metric>
    <metric>sum [costs] of irrigations</metric>
    <metric>sum [demand] of irrigations / sum [area] of irrigations</metric>
    <metric>mean [hh-size] of households</metric>
    <metric>count irrigations with [crop-type = 0]</metric>
    <metric>count irrigations with [crop-type = 1]</metric>
    <metric>count irrigations with [crop-type = 2]</metric>
    <metric>count irrigations with [crop-type = 3]</metric>
    <metric>mean [tech-factor] of households</metric>
    <metric>mean [irrigation-type] of irrigations</metric>
    <metric>count drought?</metric>
    <enumeratedValueSet variable="hh-tech-improve?">
      <value value="true"/>
    </enumeratedValueSet>
    <steppedValueSet variable="scarcity-distribution" first="0" step="0.25" last="1"/>
    <enumeratedValueSet variable="agro-tech-improve?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="agro-learn?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="storage-expansion-factor">
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="minimum-flow" first="200" step="50" last="250"/>
    <steppedValueSet variable="drought-possibility" first="0.05" step="0.05" last="0.2"/>
    <enumeratedValueSet variable="hh-learning?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
