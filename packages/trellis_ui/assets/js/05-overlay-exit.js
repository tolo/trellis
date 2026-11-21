const animatedOverlays = matchMedia('(prefers-reduced-motion: no-preference)');
const nativeOverlayExit = CSS.supports('overlay', 'auto') && CSS.supports('interactivity', 'inert');
let suppressOverlayExit = false;
const overlayExits = new WeakMap();
const overlayFade = { duration: 160, easing: 'ease-out', fill: 'both' };

function clearOverlayExit(surface) {
  const exit = overlayExits.get(surface);
  if (!exit) return;
  overlayExits.delete(surface);
  cancelAnimationFrame(exit.frame);
  exit.animation?.cancel();
  if (exit.layer === surface) surface.removeAttribute('data-trellis-overlay-exit');
  else exit.layer.remove();
}

function startOverlayExit(surface) {
  if (suppressOverlayExit || !animatedOverlays.matches) return;
  // A same-task open and close can precede the popup's placement handler.
  // Painting that unpositioned box would show a surface the reader never saw.
  if (!surface.hasAttribute('data-open')) return;
  if (surface.localName === 'dialog' && !surface.matches(':modal')) return;
  const exit = nativeOverlayExit ? { layer: surface } : exitLayer(surface);
  if (!exit) return;
  overlayExits.set(surface, exit);
  if (nativeOverlayExit) {
    const { opacity, transform, translate, scale } = getComputedStyle(surface);
    const frame = { opacity, transform, translate, scale };
    surface.dataset.trellisOverlayExit = 'native';
    // A close can interrupt the entry animation. Freeze its rendered position.
    exit.animation = surface.animate([frame, { ...frame, opacity: 0 }], overlayFade);
    releaseAfterFade(surface, exit);
    return;
  }
  // A native Escape can continue its default close after the beforetoggle
  // microtasks. Enter the fallback top layer after that operation, before paint.
  exit.frame = requestAnimationFrame(() => {
    if (!surface.isConnected) return clearOverlayExit(surface);
    exit.animation = animateOverlayExit(exit);
    releaseAfterFade(surface, exit);
  });
}

function releaseAfterFade(surface, exit) {
  const release = () => {
    if (overlayExits.get(surface) === exit) clearOverlayExit(surface);
  };
  exit.animation.finished.then(release, release);
}

function withoutOverlayExit(close) {
  const previous = suppressOverlayExit;
  suppressOverlayExit = true;
  try { close(); } finally { suppressOverlayExit = previous; }
}

function exitLayer(surface) {
  const box = surface.getBoundingClientRect();
  const paint = getComputedStyle(surface);
  if (!box.width || !box.height || paint.visibility !== 'visible') return null;

  const layer = document.createElement('div');
  layer.dataset.trellisOverlayExit = '';
  layer.inert = true;
  layer.setAttribute('aria-hidden', 'true');
  layer.setAttribute('hx-disable', '');
  layer.popover = 'manual';
  layer.className = surface.className;

  const copiedStyles = [];
  for (const child of surface.childNodes) {
    const copy = copyOverlayContent(child, copiedStyles);
    if (copy) layer.append(copy);
  }

  // Firefox drops the original top layer immediately. A manual, inert
  // popover preserves pixels outside transformed or clipping ancestors.
  const styles = {};
  for (const property of [
    'background', 'border', 'border-radius', 'box-shadow', 'color', 'color-scheme',
    'direction', 'display', 'font', 'letter-spacing', 'line-height', 'overflow',
    'padding', 'text-align', 'writing-mode',
    ...Array.from(paint).filter(property => property.startsWith('--')),
  ]) {
    styles[property] = paint.getPropertyValue(property);
  }

  return {
    layer,
    box,
    styles,
    copiedStyles,
    opacity: Number(paint.opacity),
    scrollTop: surface.scrollTop,
    scrollLeft: surface.scrollLeft,
  };
}

function animateOverlayExit(snapshot) {
  const { layer, box, styles, copiedStyles, opacity, scrollTop, scrollLeft } = snapshot;
  document.body.append(layer);
  for (const [property, value] of Object.entries(styles)) layer.style.setProperty(property, value);
  Object.assign(layer.style, {
    boxSizing: 'border-box', position: 'fixed', inset: 'auto', margin: '0',
    left: `${box.left}px`, top: `${box.top}px`,
    width: `${box.width}px`, height: `${box.height}px`,
    minWidth: '0', minHeight: '0', maxWidth: 'none', maxHeight: 'none',
    pointerEvents: 'none', transform: 'none', translate: 'none',
    animation: 'none', transition: 'none',
  });
  for (const [copy, style] of copiedStyles) Object.assign(copy.style, style);
  layer.showPopover();
  layer.scrollTop = scrollTop;
  layer.scrollLeft = scrollLeft;
  return layer.animate([{ opacity }, { opacity: 0 }], overlayFade);
}


const overlayGraphicTags = new Set(
  'svg g path rect circle ellipse line polyline polygon text tspan'.split(' '),
);
const overlayGraphicAttributes = new Set(
  ('viewBox width height x y x1 x2 y1 y2 cx cy r rx ry d points transform ' +
    'fill fill-rule fill-opacity stroke stroke-dasharray stroke-linecap stroke-linejoin stroke-opacity ' +
    'stroke-width opacity preserveAspectRatio vector-effect').split(' '),
);
const overlayTextAttributes = new Set(
  'class dir lang hidden open type disabled readonly multiple selected checked rows cols size min max step placeholder'.split(' '),
);

function copyOverlayContent(node, copiedStyles) {
  if (node.nodeType === Node.TEXT_NODE) return document.createTextNode(node.textContent);
  if (!(node instanceof Element) ||
      node.matches('script, style, link, iframe, object, embed, base, meta, source, template, dialog, [popover]')) {
    return null;
  }

  const svg = node.namespaceURI === 'http://www.w3.org/2000/svg';
  if (svg && !overlayGraphicTags.has(node.localName)) return null;
  if (!svg && !(node instanceof HTMLElement)) return null;

  const raster = node.matches('img, canvas, video');
  const wrapper = !svg && (node.localName.includes('-') || node.matches('form, audio, picture'));
  const tag = raster ? 'canvas' : wrapper ? 'div' : node.localName;
  // Only create presentational children. Identity, action, form and resource
  // attributes never enter the exit tree, even when an app supplies the slots.
  const copy = svg ? document.createElementNS(node.namespaceURI, tag) : document.createElement(tag);
  for (const { name, value } of node.attributes) {
    if ((svg && overlayGraphicAttributes.has(name) && !/url\(/i.test(value)) || overlayTextAttributes.has(name) ||
        (name.startsWith('data-') && !name.startsWith('data-hx-'))) {
      copy.setAttribute(name, value);
    }
  }

  if (raster) {
    const { width, height } = node.getBoundingClientRect();
    if (!width || !height) return null;
    copy.width = Math.ceil(width);
    copy.height = Math.ceil(height);
    const hasPixels = (node.matches('canvas') && node.width > 0 && node.height > 0) ||
      (node.matches('img') && node.complete && node.naturalWidth > 0) ||
      (node.matches('video') && node.readyState >= 2);
    if (hasPixels) copy.getContext('2d')?.drawImage(node, 0, 0, copy.width, copy.height);
    copiedStyles.push([copy, { width: `${width}px`, height: `${height}px` }]);
    return copy;
  }

  if (wrapper) copiedStyles.push([copy, { display: getComputedStyle(node).display }]);
  for (const child of node.childNodes) {
    const content = copyOverlayContent(child, copiedStyles);
    if (content) copy.append(content);
  }
  if (node.matches('select[multiple]')) {
    Array.from(copy.options).forEach((option, index) => { option.selected = node.options[index].selected; });
  } else if (node.matches('select, textarea, input:not([type=file])')) {
    copy.value = node.value;
  }
  if (node.matches('input')) copy.checked = node.checked;
  return copy;
}
