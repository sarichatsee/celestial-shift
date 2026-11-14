/* base.js: LNS.Base, the picture of the Moon base.
 *
 * PLACEHOLDER for milestone M3: sky, ground and one dome. The full picture
 * (rooms, battery bank, greenhouse, shield layers, shelter) arrives in M7 with
 * the same two functions: mount(element) once, then update(view) after every change.
 */
(function (root) {
  "use strict";
  var LNS = root.LNS = root.LNS || {};
  var host = null;

  function mount(element) {
    host = element;
    host.innerHTML =
      '<svg class="base-svg" viewBox="0 0 800 300" preserveAspectRatio="xMidYMid slice" aria-hidden="true">' +
      '<rect class="sky" width="800" height="300"/>' +
      '<circle class="sun" cx="660" cy="70" r="34"/>' +
      '<g class="stars"><circle cx="90" cy="50" r="2"/><circle cx="210" cy="90" r="1.5"/><circle cx="330" cy="40" r="2"/>' +
      '<circle cx="470" cy="80" r="1.5"/><circle cx="560" cy="30" r="2"/><circle cx="730" cy="110" r="1.5"/></g>' +
      '<circle class="earth" cx="140" cy="80" r="26"/>' +
      '<path class="ground" d="M0 230 Q400 190 800 230 L800 300 L0 300 Z"/>' +
      '<path class="dome" d="M300 226 A100 100 0 0 1 500 226 Z"/>' +
      '</svg>';
  }

  function update(view) {
    if (!host) return;
    host.classList.toggle("is-day", !!view.isDay);
    host.classList.toggle("is-night", !view.isDay);
    host.classList.toggle("ls-ok", !!view.lifeSupportOk);
  }

  LNS.Base = { mount: mount, update: update };
})(globalThis);
