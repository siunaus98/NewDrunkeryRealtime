$root = Join-Path (Get-Location) 'ArtResource\Generated'
$dishDir = Join-Path $root 'Dish'
$stateDir = Join-Path $root 'Process'
New-Item -ItemType Directory -Force -Path $dishDir, $stateDir | Out-Null

$items = @(
    @{id='drink_oasis_wine'; kind='drink'; hue='#d85b62'; accent='#ffd27a'},
    @{id='drink_gold_ale'; kind='drink'; hue='#d7a52d'; accent='#fff0a6'},
    @{id='drink_qingmei_wine'; kind='drink'; hue='#7bb7e8'; accent='#d9f4ff'},
    @{id='dish_crisp_plate'; kind='plate'; hue='#5fae55'; accent='#ffd878'},
    @{id='dish_sand_potato_plate'; kind='plate'; hue='#c58b42'; accent='#f5d58b'},
    @{id='dish_golden_flatbread'; kind='flat'; hue='#d49b35'; accent='#fff0a6'},
    @{id='dish_red_roll'; kind='roll'; hue='#bd4e45'; accent='#6fbe62'},
    @{id='dish_white_plate'; kind='plate'; hue='#ded7bf'; accent='#bd5b4f'},
    @{id='dish_sand_potato_cutlet'; kind='cutlet'; hue='#b97935'; accent='#71b85f'},
    @{id='dish_fowl_sand_roll'; kind='roll'; hue='#e3c777'; accent='#b9564b'},
    @{id='dish_red_double_roast'; kind='stack'; hue='#a93f37'; accent='#f1a24b'},
    @{id='dish_golden_fowl_cake'; kind='cake'; hue='#d69d38'; accent='#e86a5b'},
    @{id='drink_qingmei_light_ferment'; kind='drink'; hue='#71a8d6'; accent='#f7d77c'},
    @{id='drink_double_ferment'; kind='drink'; hue='#9f6a43'; accent='#e9b85c'},
    @{id='drink_stoneflower_honey'; kind='drink'; hue='#d79b32'; accent='#8ecf78'},
    @{id='drink_sunwheel_infusion'; kind='drink'; hue='#e77843'; accent='#ffe18a'},
    @{id='dish_dryfrost_roll'; kind='roll'; hue='#8fb7a2'; accent='#e6d28d'},
    @{id='dish_sunseed_crisp'; kind='flat'; hue='#dca63e'; accent='#7dbb54'},
    @{id='dish_dill_sand_potato_cup'; kind='cup'; hue='#b9793b'; accent='#7cbf72'},
    @{id='dish_qingmei_leaf_shard'; kind='shard'; hue='#6dae65'; accent='#81b7df'},
    @{id='dish_stoneflower_baked_cup'; kind='cup'; hue='#c17b49'; accent='#e1bd5f'},
    @{id='dish_hare_skewer'; kind='skewer'; hue='#c77055'; accent='#7bbd62'},
    @{id='dish_fowl_pot'; kind='pot'; hue='#a75c45'; accent='#d3b15c'},
    @{id='dish_oasis_hotpot'; kind='pot'; hue='#b94f3f'; accent='#edbe57'},
    @{id='dish_dill_fowl_pot'; kind='pot'; hue='#8c7544'; accent='#77b86a'},
    @{id='dish_dryfrost_meat_wrap'; kind='wrap'; hue='#8b6350'; accent='#a6c96c'},
    @{id='dish_camel_thin_roast'; kind='cutlet'; hue='#a94e3c'; accent='#e3b14f'},
    @{id='dish_qingmei_sweet_bowl'; kind='bowl'; hue='#d07b9c'; accent='#d4ec88'},
    @{id='dish_golden_baked_cake'; kind='cake'; hue='#d4a041'; accent='#e8d27e'},
    @{id='dish_stoneflower_frozen'; kind='bowl'; hue='#76a9c2'; accent='#f1d779'},
    @{id='drink_royal_aged'; kind='drink'; hue='#75496e'; accent='#e9c46b'},
    @{id='drink_moon_dew'; kind='drink'; hue='#7695cf'; accent='#f2e3a2'},
    @{id='drink_scorch_double_ferment'; kind='drink'; hue='#b95331'; accent='#f2c056'},
    @{id='dish_royal_roast_plate'; kind='platter'; hue='#9d4a3e'; accent='#d9b85d'},
    @{id='dish_stoneflower_cold_plate'; kind='platter'; hue='#6f9e79'; accent='#d6c67a'},
    @{id='dish_qingmei_seared_cup'; kind='cup'; hue='#c96762'; accent='#8fc78b'},
    @{id='dish_spiced_lamb'; kind='cutlet'; hue='#934336'; accent='#d5973f'},
    @{id='dish_camel_double_roast'; kind='stack'; hue='#7f3f35'; accent='#d99e43'},
    @{id='dish_royal_heat_plate'; kind='platter'; hue='#b84c39'; accent='#f0c357'},
    @{id='dish_wine_platter'; kind='platter'; hue='#794557'; accent='#d9a75a'},
    @{id='dish_sunrise_banquet'; kind='platter'; hue='#d36a3d'; accent='#f1d27c'},
    @{id='dish_stoneflower_honey_feast'; kind='platter'; hue='#c28b39'; accent='#8bc477'}
)

$shapes = @{
    drink = '<ellipse cx="32" cy="38" rx="17" ry="5" fill="{0}"/><path d="M18 22h28l-3 17H21z" fill="{0}"/><rect x="28" y="12" width="8" height="10" fill="{1}"/><rect x="25" y="9" width="14" height="4" fill="#f6e6b0"/><rect x="22" y="25" width="20" height="4" fill="{1}"/>'
    plate = '<ellipse cx="32" cy="43" rx="24" ry="8" fill="#ead9a8"/><ellipse cx="32" cy="36" rx="20" ry="11" fill="{0}"/><rect x="22" y="31" width="8" height="6" fill="{1}"/><rect x="34" y="29" width="9" height="8" fill="{1}"/><rect x="28" y="39" width="12" height="4" fill="#4f7c49"/>'
    flat = '<path d="M10 40L18 19L47 16L55 39L45 51L17 49Z" fill="#e7d29b"/><path d="M16 38L22 23L43 21L49 37L42 44L21 43Z" fill="{0}"/><rect x="24" y="27" width="12" height="5" fill="{1}"/><rect x="19" y="35" width="19" height="4" fill="{1}"/>'
    roll = '<path d="M14 20L46 16L52 42L20 48Z" fill="#e5d09c"/><path d="M18 22L43 19L47 38L22 43Z" fill="{0}"/><rect x="27" y="23" width="7" height="20" fill="{1}"/><rect x="21" y="31" width="24" height="4" fill="#f5dfa0"/>'
    cutlet = '<path d="M10 37L22 17L48 18L55 35L44 49L17 47Z" fill="{0}"/><path d="M16 35L25 23L44 24L49 35L40 42L21 41Z" fill="#e9be68"/><rect x="24" y="28" width="18" height="4" fill="{1}"/><rect x="20" y="37" width="8" height="4" fill="#713d35"/>'
    stack = '<ellipse cx="32" cy="44" rx="22" ry="6" fill="#5c3d32"/><path d="M13 34L21 19L46 18L52 34L44 41L20 41Z" fill="{0}"/><path d="M17 27L25 13L46 15L49 27L42 34L21 33Z" fill="{1}"/><rect x="26" y="22" width="15" height="4" fill="#f1d07d"/>'
    cake = '<path d="M13 39L18 22L46 20L52 38L42 49L21 48Z" fill="{0}"/><rect x="19" y="26" width="27" height="5" fill="{1}"/><rect x="22" y="35" width="24" height="5" fill="#f3d889"/><rect x="28" y="17" width="9" height="5" fill="{1}"/>'
    cup = '<path d="M16 22H48L44 45L21 45Z" fill="#e8d5a4"/><path d="M20 25H44L41 40H23Z" fill="{0}"/><rect x="24" y="28" width="14" height="4" fill="{1}"/><rect x="28" y="35" width="9" height="4" fill="{1}"/>'
    shard = '<path d="M12 38L22 15L49 22L39 48Z" fill="{0}"/><path d="M21 34L26 22L42 26L36 42Z" fill="{1}"/><rect x="28" y="28" width="5" height="14" fill="#f3d98a"/>'
    skewer = '<rect x="12" y="29" width="40" height="4" fill="#d8a55d"/><rect x="17" y="21" width="10" height="17" fill="{0}"/><rect x="29" y="19" width="10" height="19" fill="{1}"/><rect x="41" y="23" width="8" height="14" fill="{0}"/><rect x="10" y="27" width="44" height="2" fill="#f0d08a"/>'
    pot = '<path d="M13 23H51L47 46L39 51H25L17 46Z" fill="#6b473c"/><rect x="18" y="25" width="28" height="14" fill="{0}"/><rect x="23" y="29" width="8" height="5" fill="{1}"/><rect x="35" y="27" width="9" height="6" fill="{1}"/><rect x="20" y="18" width="24" height="5" fill="#d3a85d"/>'
    wrap = '<path d="M12 21L47 16L53 41L18 49Z" fill="#d9c184"/><path d="M18 24L43 20L47 38L22 43Z" fill="{0}"/><rect x="27" y="22" width="5" height="21" fill="{1}"/><rect x="36" y="21" width="5" height="20" fill="#eacb76"/>'
    bowl = '<path d="M12 25H52L46 45L39 50H25L18 45Z" fill="#e6d3a0"/><path d="M17 27H47L42 40L36 44H27L21 40Z" fill="{0}"/><rect x="24" y="30" width="10" height="5" fill="{1}"/><rect x="37" y="33" width="7" height="4" fill="{1}"/>'
    platter = '<ellipse cx="32" cy="41" rx="24" ry="9" fill="#e8d49e"/><path d="M11 36L21 18L35 23L47 17L54 36L45 45L20 45Z" fill="{0}"/><rect x="20" y="29" width="10" height="6" fill="{1}"/><rect x="34" y="27" width="12" height="6" fill="{1}"/><rect x="27" y="37" width="13" height="4" fill="#7db96a"/>'
}

# Prototype dish language: plate silhouette communicates category, rim color
# communicates rarity, and the two-digit code identifies the exact recipe.
# Drinks deliberately keep their distinct bottle/glass artwork.
$smallPlateIds = @(
    'dish_crisp_plate','dish_sand_potato_plate','dish_golden_flatbread',
    'dish_dryfrost_roll','dish_sunseed_crisp','dish_dill_sand_potato_cup',
    'dish_qingmei_leaf_shard','dish_stoneflower_baked_cup',
    'dish_royal_roast_plate','dish_stoneflower_cold_plate','dish_qingmei_seared_cup'
)
$mainDishIds = @(
    'dish_red_roll','dish_white_plate','dish_sand_potato_cutlet',
    'dish_fowl_sand_roll','dish_red_double_roast','dish_golden_fowl_cake',
    'dish_hare_skewer','dish_fowl_pot','dish_oasis_hotpot','dish_dill_fowl_pot',
    'dish_dryfrost_meat_wrap','dish_camel_thin_roast','dish_spiced_lamb',
    'dish_camel_double_roast','dish_royal_heat_plate','dish_wine_platter'
)
$dessertIds = @(
    'dish_qingmei_sweet_bowl','dish_golden_baked_cake','dish_stoneflower_frozen',
    'dish_sunrise_banquet','dish_stoneflower_honey_feast'
)
$tierOneIds = @(
    'dish_crisp_plate','dish_sand_potato_plate','dish_golden_flatbread',
    'dish_red_roll','dish_white_plate','dish_sand_potato_cutlet',
    'dish_fowl_sand_roll','dish_red_double_roast','dish_golden_fowl_cake'
)
$tierThreeIds = @(
    'dish_royal_roast_plate','dish_stoneflower_cold_plate','dish_qingmei_seared_cup',
    'dish_spiced_lamb','dish_camel_double_roast','dish_royal_heat_plate',
    'dish_wine_platter','dish_sunrise_banquet','dish_stoneflower_honey_feast'
)

$digitRows = @{
    '0'=@('111','101','101','101','111'); '1'=@('010','110','010','010','111')
    '2'=@('111','001','111','100','111'); '3'=@('111','001','111','001','111')
    '4'=@('101','101','111','001','001'); '5'=@('111','100','111','001','111')
    '6'=@('111','100','111','101','111'); '7'=@('111','001','010','010','010')
    '8'=@('111','101','111','101','111'); '9'=@('111','101','111','001','111')
}

function Get-PixelNumberSvg([int]$number) {
    $text = $number.ToString('00')
    $result = ''
    $digitWidth = 12
    $pixel = 4
    $startX = 18
    for ($digitIndex = 0; $digitIndex -lt 2; $digitIndex++) {
        $rows = $digitRows[$text.Substring($digitIndex, 1)]
        for ($y = 0; $y -lt 5; $y++) {
            for ($x = 0; $x -lt 3; $x++) {
                if ($rows[$y].Substring($x, 1) -eq '1') {
                    $px = $startX + $digitIndex * ($digitWidth + 4) + $x * $pixel
                    $py = 19 + $y * $pixel
                    $result += "<rect x='$px' y='$py' width='$pixel' height='$pixel' fill='#fff4cf'/>"
                }
            }
        }
    }
    return $result
}

function Get-StandardDishSvg($item, [string]$category, [int]$number) {
    $rim = if ($tierOneIds -contains $item.id) { '#72b96d' } elseif ($tierThreeIds -contains $item.id) { '#c987db' } else { '#e0ad45' }
    $plate = switch ($category) {
        'small' { "<circle cx='32' cy='31' r='25' fill='#211b22'/><circle cx='32' cy='31' r='22' fill='$rim'/><circle cx='32' cy='31' r='17' fill='#44383f'/>" }
        'main' { "<rect x='7' y='6' width='50' height='50' fill='#211b22'/><rect x='10' y='9' width='44' height='44' fill='$rim'/><rect x='15' y='14' width='34' height='34' fill='#44383f'/>" }
        'dessert' { "<path d='M18 5H46L59 31L46 57H18L5 31Z' fill='#211b22'/><path d='M20 9H44L54 31L44 53H20L10 31Z' fill='$rim'/><path d='M23 14H41L49 31L41 48H23L15 31Z' fill='#44383f'/>" }
    }
    $numberSvg = Get-PixelNumberSvg $number
    $garnish = "<rect x='19' y='43' width='12' height='4' fill='$($item.hue)'/><rect x='33' y='43' width='12' height='4' fill='$($item.accent)'/>"
    return "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64' shape-rendering='crispEdges'><rect width='64' height='64' fill='none'/>$plate$numberSvg$garnish</svg>"
}

foreach ($item in $items) {
    if ($item.kind -eq 'drink') {
        $shape = $shapes[$item.kind] -f $item.hue, $item.accent
        $svg = "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64' shape-rendering='crispEdges'><rect width='64' height='64' fill='none'/><rect x='8' y='8' width='48' height='48' fill='#1b1720' opacity='.22'/>$shape<rect x='8' y='52' width='48' height='4' fill='#231b24' opacity='.55'/></svg>"
    }
    else {
        if ($smallPlateIds -contains $item.id) { $category = 'small'; $number = [array]::IndexOf($smallPlateIds, $item.id) + 1 }
        elseif ($mainDishIds -contains $item.id) { $category = 'main'; $number = [array]::IndexOf($mainDishIds, $item.id) + 1 }
        else { $category = 'dessert'; $number = [array]::IndexOf($dessertIds, $item.id) + 1 }
        $svg = Get-StandardDishSvg $item $category $number
    }
    Set-Content -LiteralPath (Join-Path $dishDir ($item.id + '.svg')) -Value $svg -Encoding utf8
}

$states = @{
    cut = @{main='#6dd27b'; accent='#e8f5ad'; mark='cross'}
    roast_rare = @{main='#6ec6e8'; accent='#d9f7ff'; mark='one'}
    roast_medium = @{main='#f0b84b'; accent='#fff0a6'; mark='two'}
    roast_well = @{main='#d9653f'; accent='#ffd08a'; mark='three'}
    grind_coarse = @{main='#b18a57'; accent='#f0d59d'; mark='coarse'}
    grind_fine = @{main='#8fd0b0'; accent='#edffd5'; mark='fine'}
}
foreach ($name in $states.Keys) {
    $s = $states[$name]
    $marks = switch ($s.mark) {
        cross { '<rect x="29" y="17" width="6" height="30" fill="{0}"/><rect x="17" y="29" width="30" height="6" fill="{0}"/>' -f $s.accent }
        one { '<rect x="29" y="19" width="6" height="26" fill="{0}"/>' -f $s.accent }
        two { '<rect x="22" y="19" width="6" height="26" fill="{0}"/><rect x="36" y="19" width="6" height="26" fill="{0}"/>' -f $s.accent }
        three { '<rect x="16" y="19" width="6" height="26" fill="{0}"/><rect x="29" y="19" width="6" height="26" fill="{0}"/><rect x="42" y="19" width="6" height="26" fill="{0}"/>' -f $s.accent }
        coarse { '<rect x="17" y="22" width="30" height="5" fill="{0}"/><rect x="17" y="30" width="24" height="5" fill="{0}"/><rect x="17" y="38" width="18" height="5" fill="{0}"/>' -f $s.accent }
        fine { '<rect x="18" y="22" width="28" height="3" fill="{0}"/><rect x="18" y="28" width="28" height="3" fill="{0}"/><rect x="18" y="34" width="28" height="3" fill="{0}"/><rect x="18" y="40" width="28" height="3" fill="{0}"/>' -f $s.accent }
    }
    $svg = "<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32' viewBox='0 0 64 64' shape-rendering='crispEdges'><rect x='5' y='5' width='54' height='54' fill='#1b1720' opacity='.88'/><rect x='9' y='9' width='46' height='46' fill='$($s.main)'/><rect x='13' y='13' width='38' height='38' fill='#342338' opacity='.28'/>$marks<rect x='9' y='9' width='46' height='4' fill='#ffffff' opacity='.28'/></svg>"
    Set-Content -LiteralPath (Join-Path $stateDir ($name + '.svg')) -Value $svg -Encoding utf8
}
