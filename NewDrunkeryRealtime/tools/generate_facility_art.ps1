$ErrorActionPreference = 'Stop'
$artRoot = Join-Path (Get-Location) 'ArtResource/Facilities'
[IO.Directory]::CreateDirectory($artRoot) | Out-Null
# Shared warm wood, muted metal, thick brown contours; no raster generation
# or runtime texture rendering. Each symbol is authored separately.
$symbols = @{
flyer = '<path d="M30 34h68v56H30z" fill="#79988a"/><path d="M43 24h42v49H43z" fill="#f3dfac"/><path d="M51 35h25m-25 9h20m-20 9h25" fill="none"/><path d="M24 85h80v18H24z" fill="#d9b679"/><path d="M42 79h44v10H42z" fill="#513420"/><path d="M96 21l10-8m-5 19h12" fill="none" stroke="#cba354"/>'
fire_furnace = '<path d="M24 29h80v74H24z" fill="#aa6e48"/><path d="M39 57q25-30 50 0v35H39z" fill="#4b342d"/><path d="M49 86q-8-18 5-30 0 11 10 13 6-14 5-24 22 27 10 41z" fill="#ec933f"/><path d="M58 86q-3-12 8-18l5 18z" fill="#ffe296"/><path d="M31 37h66m-69 63h72" fill="none" stroke="#d8ad73"/><path d="M42 12h44v15H42z" fill="#8b7162"/>'
water_dispenser = '<path d="M32 22h64v80H32z" fill="#e0c389"/><path d="M43 15q21-12 42 0v36q-21 13-42 0z" fill="#8bc7cc"/><path d="M50 19v23m7-25v25" fill="none" stroke="#c9e8dc"/><path d="M40 62h48v31H40z" fill="#6b5b48"/><path d="M60 51v14h13v8" fill="none" stroke="#d0d6bd" stroke-width="7"/><path d="M56 78h22l-3 17H59z" fill="#9fd3ce"/>'
net_rack = '<path d="M24 30h80v10H24zm6 8v62m68-62v62" fill="#b68951"/><path d="M35 44h58l-8 40H43z" fill="#78b8b3"/><path d="M37 46l45 36m-32-36l38 29m-48-8l17 15m33-36L46 80m30-34L41 68m47-2L70 82" fill="none" stroke="#e6d7a1" stroke-width="2.5"/><path d="M37 88h54v12H37z" fill="#9c7950"/>'
healing_spring = '<path d="M22 64q42-27 84 0v31q-42 22-84 0z" fill="#b6ab87"/><ellipse cx="64" cy="62" rx="42" ry="22" fill="#83c4be"/><path d="M43 61q21-13 42 0m-34 9q13 6 26 0" fill="none" stroke="#d2ebce"/><path d="M56 27h16v11h12v16H72v12H56V54H44V38h12z" fill="#e3d79a"/><path d="M36 18l4 9m52-9-4 9" fill="none" stroke="#b7dfc9"/>'
portal = '<ellipse cx="64" cy="88" rx="44" ry="16" fill="#9c8e76"/><path d="M30 85V40q0-28 34-28t34 28v45H81V42q0-14-17-14T47 42v43z" fill="#b9a87d"/><path d="M47 84V43q0-15 17-15t17 15v41z" fill="#5c969e"/><ellipse cx="64" cy="57" rx="12" ry="24" fill="#9ed5cf" stroke="#d9edcf"/><path d="M32 48l12-3m40 0 12 3M55 16l3 12m15-12-3 12" fill="none" stroke="#e0c778"/>'
duplicator = '<path d="M26 39h76v60H26z" fill="#7e9993"/><path d="M35 30h58v19H35z" fill="#cbb782"/><path d="M38 58h52v29H38z" fill="#4f6867"/><path d="M46 72h36m-8-8 8 8-8 8" fill="none" stroke="#e3d59a"/><path d="M45 24l19-13 19 13-19 13z" fill="#a6d1c1"/><path d="M28 96h72v9H28z" fill="#b48b56"/><circle cx="94" cy="52" r="5" fill="#f1d689"/>'
shuttle = '<path d="M25 36h78v64H25z" fill="#a88150"/><path d="M31 42h66v32H31z" fill="#e1c48d"/><path d="M26 87h76M41 37v62m45-62v62" fill="none" stroke="#6e6657" stroke-width="7"/><path d="M47 54h33m-10-9 10 9-10 9" fill="none" stroke="#b57b43" stroke-width="5"/>'
stack_table = '<path d="M22 39h84v62H22z" fill="#a87243"/><path d="M16 25h96v54H16z" fill="#ddbd81"/><path d="M27 35h74v33H27z" fill="#b78f59"/><path d="M34 45h25v20H34zm34-8h25v28H68z" fill="#cf9c60"/><path d="M34 41h25m9-8h25" fill="none" stroke="#f1d3a0"/><path d="M29 86h70" fill="none" stroke="#754b2c"/>'
forklift = '<path d="M24 40h78v52H24z" fill="#d1a455"/><path d="M29 31h45v41H29z" fill="#8a9f91"/><path d="M39 19h32v31H39z" fill="#e0c491"/><path d="M78 19h10v75H78z" fill="#8d8c76"/><path d="M83 85h29v9H83z" fill="#c9c7a4"/><path d="M25 33V17h48v16" fill="none" stroke-width="7"/><circle cx="37" cy="94" r="14" fill="#51483b"/><circle cx="37" cy="94" r="6" fill="#b6ac87"/><circle cx="85" cy="94" r="14" fill="#51483b"/><circle cx="85" cy="94" r="6" fill="#b6ac87"/>'
culture = '<path d="M26 39q38-17 76 0v48q-38 25-76 0z" fill="#aec3a5"/><ellipse cx="64" cy="38" rx="38" ry="16" fill="#d8dec0"/><ellipse cx="64" cy="45" rx="28" ry="10" fill="#99754e"/><path d="M64 77V50q-23 4-25-16 24-2 25 16 5-21 26-17-4 19-26 17" fill="#86aa69"/><path d="M35 63v19m8-18v15" fill="none" stroke="#d9e8c8"/><path d="M25 91q39 20 78 0v11q-39 17-78 0z" fill="#aa8659"/>'
trap_rack = '<path d="M25 29h78v73H25z" fill="#b68750"/><path d="M20 24h88v15H20z" fill="#ddba7d"/><path d="M39 74q25-34 50 0l-5 16H44z" fill="#8f9587"/><path d="M39 73l6-11 6 7 7-15 7 11 8-10 6 14 9-6" fill="none" stroke="#ded7b0"/><circle cx="64" cy="81" r="8" fill="#aa905b"/>'
ballista = '<path d="M27 41h74v58H27z" fill="#ad8250"/><path d="M34 31h60v23H34z" fill="#d4b67e"/><path d="M36 65h56v19H36z" fill="#917856"/><path d="M64 17v72" fill="none" stroke="#e1c28a" stroke-width="10"/><path d="M23 34q41 31 82 0M24 33l40 35 40-35" fill="none" stroke="#6e8177" stroke-width="6"/><path d="M64 9l-8 15h16z" fill="#c3d1b8"/>'
}
$base = '<ellipse cx="64" cy="112" rx="48" ry="9" fill="#513420" opacity=".16" stroke="none"/><path d="M21 67h86v37l-9 8H30l-9-8z" fill="#a87845"/><path d="M21 67l9-8h68l9 8-9 11H30z" fill="#cfab73"/>'
foreach ($name in $symbols.Keys) {
 $svg = '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="144" viewBox="0 0 128 144"><g stroke="#513420" stroke-width="4" stroke-linejoin="round" stroke-linecap="round">' + $base + $symbols[$name] + '</g></svg>'
 [IO.File]::WriteAllText((Join-Path $artRoot "$name.svg"), $svg, [Text.UTF8Encoding]::new($false))
}
$tools = @{
ice_water = '<path d="M35 34h58l-7 64H42z" fill="#9accc7"/><path d="M42 47h44l-5 43H47z" fill="#b8e2d4"/><path d="M45 40l16-4 4 16-16 4zm24 18 14-4 4 14-14 4z" fill="#e9edc9"/><ellipse cx="64" cy="34" rx="29" ry="10" fill="#d9e7ca"/>'
magic_net = '<path d="M23 27h68L79 81H35z" fill="#77b8b0"/><path d="M26 30l48 48M43 28l42 42M28 51l26 28M87 31L39 78M70 28L32 66M82 53L56 80" fill="none" stroke="#e5d3a1" stroke-width="3"/><path d="M84 75l22 33" fill="none" stroke="#b98b51" stroke-width="8"/>'
bear_trap = '<ellipse cx="64" cy="77" rx="45" ry="23" fill="#8b9385"/><path d="M21 65l9-18 10 13 11-22 13 19 12-19 11 22 12-13 9 18" fill="#c7cdb2"/><path d="M25 75l8 12 12-10 10 17 11-14 11 14 10-17 10 10 8-12" fill="none" stroke="#e4d9ad"/><ellipse cx="64" cy="73" rx="16" ry="9" fill="#ad8f56"/>'
transit_orb = '<circle cx="64" cy="64" r="28" fill="#72bec4" stroke="#d6eed5"/><circle cx="58" cy="55" r="11" fill="#e7f0cb" stroke="none"/>'
shuttle_cart = '<circle cx="34" cy="94" r="11" fill="#637166"/><circle cx="94" cy="94" r="11" fill="#637166"/><path d="M21 46h86l-10 44H31z" fill="#c69b60"/><path d="M24 42h80v15H24z" fill="#e0be7d"/><path d="M40 59v24m24-24v24m24-24v24" fill="none" stroke="#8e6339"/>'
}
foreach ($name in $tools.Keys) {
 $svg = '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><g stroke="#513420" stroke-width="4" stroke-linejoin="round" stroke-linecap="round">' + $tools[$name] + '</g></svg>'
 [IO.File]::WriteAllText((Join-Path $artRoot "$name.svg"), $svg, [Text.UTF8Encoding]::new($false))
}
$supportArt = @{
lamp = '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="144" viewBox="0 0 128 144"><g stroke="#513420" stroke-width="4" stroke-linejoin="round"><ellipse cx="64" cy="115" rx="43" ry="8" fill="#513420" opacity=".16" stroke="none"/><path d="M25 70h78v35H25z" fill="#a87b46"/><ellipse cx="64" cy="70" rx="42" ry="20" fill="#d5b77e"/><path d="M58 39h12v40H58z" fill="#a18a59"/><path d="M40 15h48l17 33H23z" fill="#e9cd7f"/><path d="M48 18l-4 26m35-26 5 26" stroke="#ffe6a5"/><ellipse cx="64" cy="48" rx="40" ry="10" fill="#efdca1"/><ellipse cx="64" cy="76" rx="20" ry="8" fill="#d5bb81"/></g></svg>'
conveyor = '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="144" viewBox="0 0 256 144"><g stroke="#513420" stroke-width="4" stroke-linejoin="round"><path d="M8 40h240v65H8z" fill="#a57b4a"/><path d="M8 29h240v62H8z" fill="#8d9e8e"/><path d="M22 41h212v36H22z" fill="#687b70"/><path d="M36 41v36m27-36v36m27-36v36m27-36v36m27-36v36m27-36v36m27-36v36m27-36v36" stroke="#b6b593" stroke-width="6"/><path d="M42 55h134V44l30 16-30 16V65H42z" fill="#ebce88" stroke-width="3"/><path d="M15 95h226" stroke="#d5b578"/></g></svg>'
}
foreach ($name in $supportArt.Keys) {
 [IO.File]::WriteAllText((Join-Path $artRoot "$name.svg"), $supportArt[$name], [Text.UTF8Encoding]::new($false))
}
