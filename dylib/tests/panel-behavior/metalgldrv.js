// The OpenGL section turns metalgldrv on for a game, offers its own settings only while
// it is on, and clears them when it is turned off. The FEX build has no such section.
'use strict';
const { panel, walk, details, runner, FORMS } = require('./harness');

const emit = process.argv[2];
if (!emit) { console.error('usage: metalgldrv.js <emit>'); process.exit(2); }

const SWITCH = "metalgldrv (OpenGL 4.6 on Metal instead of Apple's OpenGL 4.1)";
const FEX_TOOLS = ['notproton-fex'];

let failed = 0;
for (const form of Object.keys(FORMS)) {
  const { render: P, pick, written } = panel(emit, form, undefined, { fexTools: FEX_TOOLS });
  const t = runner(form);
  const nodes = (opts, tool = 'notproton-rosetta') =>
    walk(P({ details: details(opts, { strCompatToolName: tool }) }));
  const row = (ns, label) => ns.find(x => x.type === 'Toggle' && x.props.label === label);
  const section = (ns, label) => ns.find(x => x.type === 'Section' && x.props.label === label);
  const last = () => written[written.length - 1].opts;

  let r = nodes('%command%');
  t.ok(section(r, 'OpenGL') && row(r, SWITCH).props.checked === false, 'off unless the game turns it on');
  t.ok(!row(r, 'MetalFX upscaling') && !section(r, 'metalgldrv accuracy'),
       'its settings stay hidden while it is off');

  written.length = 0;
  row(r, SWITCH).props.onChange(true);
  t.ok(last() === 'NOTPROTON_METALGLDRV=1 %command%', `turning it on writes the switch (${last()})`);

  r = nodes('NOTPROTON_METALGLDRV=1 %command%');
  t.ok(row(r, SWITCH).props.checked === true, 'the switch reads back');
  t.ok(row(r, 'MetalFX upscaling') && section(r, 'metalgldrv accuracy'), 'its settings appear');
  const acc = section(r, 'metalgldrv accuracy').props.children;
  t.ok(acc.props.selectedOption === '' &&
       acc.props.rgOptions.map(o => o.data).join() ===
       ',METALGLDRV_STRICT,METALGLDRV_TURBOHAX,METALGLDRV_SPEEDDEMON', 'default accuracy and its choices');

  written.length = 0;
  acc.props.onChange({ data: 'METALGLDRV_TURBOHAX' });
  t.ok(last() === 'METALGLDRV_TURBOHAX=1 NOTPROTON_METALGLDRV=1 %command%', `picking turbo (${last()})`);
  r = nodes('NOTPROTON_METALGLDRV=1 METALGLDRV_STRICT=1 %command%');
  section(r, 'metalgldrv accuracy').props.children.props.onChange({ data: 'METALGLDRV_SPEEDDEMON' });
  t.ok(last() === 'METALGLDRV_SPEEDDEMON=1 NOTPROTON_METALGLDRV=1 %command%',
       `picking another profile drops the previous one (${last()})`);
  t.ok(section(nodes('NOTPROTON_METALGLDRV=1 METALGLDRV_STRICT=1 %command%'), 'metalgldrv accuracy')
       .props.children.props.selectedOption === 'METALGLDRV_STRICT', 'the profile reads back');

  r = nodes('NOTPROTON_METALGLDRV=1 METALGLDRV_USE_METALFX=1 METALGLDRV_STRICT=1 MTL_HUD_ENABLED=1 %command% -windowed');
  t.ok(row(r, 'MetalFX upscaling').props.checked === true, 'MetalFX reads back');
  row(r, SWITCH).props.onChange(false);
  t.ok(last() === 'MTL_HUD_ENABLED=1 %command% -windowed',
       `turning it off clears its settings and keeps the rest (${last()})`);

  r = nodes('NOTPROTON_METALGLDRV=1 %command%', 'notproton-fex');
  t.ok(!section(r, 'OpenGL') && !section(r, 'metalgldrv accuracy') && !row(r, 'MetalFX upscaling'),
       'the FEX build shows no OpenGL section');

  if (pick) {
    written.length = 0;
    pick(details('NOTPROTON_METALGLDRV=1 MTL_HUD_ENABLED=1 %command%'), 'notproton-fex');
    t.ok(last() === 'MTL_HUD_ENABLED=1 %command%', `picking a FEX tool clears the switch (${last()})`);
  }
  failed += t.failed;
}
if (failed) { console.error(`${failed} failure(s)`); process.exit(1); }
console.log('PASS: metalgldrv switch, its settings, and the FEX build');
