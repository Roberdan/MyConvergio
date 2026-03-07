function esc(s) {
  const d = document.createElement("div");
  d.textContent = s;
  return d.innerHTML;
}
