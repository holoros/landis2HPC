# Plains/Rockies LANDIS extension-species scaffolds

Data-driven target lists for the 5 clusters that cannot warmstart from the eastern/PNW
floras. Built from FIA basal-area dominance (top-8 species/state). Each cluster_<C>_
extension_species.csv lists the species present, flags which are NEW vs the warmstart
parent pool (needs_literature=yes), and gives a published-LANDIS source hint. The
literature step fills longevity / maturity / tolerances / dispersal / regen, then:
freeze cluster ref theta (add_state.sh on a seed state to convergence) ->
cluster_<C>_reference_theta.csv -> onboard members.

## P1 (MN+IN (eastern broadleaf / prairie margin))
States: KS, NE, OK. Central/southern plains. Warmstart eastern broadleaf; add prairie-margin oaks, redcedar, mesquite, dry ponderosa.
10 of 18 species need LANDIS SpeciesData from literature.
New species: post oak, ponderosa pine, bur oak, hackberry, eastern redcedar, Osage-orange, blackjack oak, honeylocust, winged elm, red mulberry

## P2 (MN (northern hardwood / aspen parkland))
States: ND, SD. Northern plains + Black Hills. SD is ponderosa-dominated (Black Hills); add ponderosa, RM juniper, bur oak.
4 of 10 species need LANDIS SpeciesData from literature.
New species: ponderosa pine, bur oak, eastern cottonwood, Rocky Mountain juniper

## R1 (WA (PNW conifer))
States: MT, ID, WY. Northern Rockies. Add lodgepole, subalpine fir, Engelmann spruce, western larch, whitebark/limber pine.
9 of 13 species need LANDIS SpeciesData from literature.
New species: lodgepole pine, Engelmann spruce, subalpine fir, ponderosa pine, Utah juniper, whitebark pine, western larch, quaking aspen, Rocky Mountain juniper

## R2 (WA + IN (mixed conifer / pinyon-juniper))
States: CO, NM, AZ, UT. Southern Rockies + Colorado Plateau. Add pinyon, junipers, Gambel oak, white fir, aspen, spruce-fir.
10 of 14 species need LANDIS SpeciesData from literature.
New species: Utah juniper, oneseed juniper, ponderosa pine, Colorado pinyon, lodgepole pine, alligator juniper, Gambel oak, Arizona white oak, Rocky Mountain juniper, white fir

## R3 (WA (sparse, pinyon-juniper end-member))
States: NV. Great Basin. Pinyon-juniper woodland end-member; add Utah juniper, singleleaf pinyon, mtn-mahogany.
7 of 8 species need LANDIS SpeciesData from literature.
New species: Utah juniper, singleleaf pinyon, curlleaf mountain-mahogany, white fir, limber pine, Jeffrey pine, western juniper
