// The KakaoTalk downloader runs outside the page and needs a public HTTP URL.
// The first argument is kept for compatibility with the existing Flutter bridge.
window.lookAtYouSaveImage = function (_blob, filename, hint, closeLabel) {
  const url = new URL('result-cards/' + encodeURIComponent(filename), document.baseURI);
  const dialog = document.createElement('dialog');
  const image = document.createElement('img');
  const help = document.createElement('p');
  const download = document.createElement('a');
  const close = document.createElement('button');
  image.src = url.href;
  image.alt = filename;
  image.style.cssText = 'display:block;width:100%;max-height:65vh;object-fit:contain;-webkit-touch-callout:default;user-select:auto';
  dialog.style.cssText = 'box-sizing:border-box;width:min(94vw,520px);max-height:92vh;overflow:auto;border:0;border-radius:16px;background:#fff9f2;color:#4a2e1e;padding:16px;text-align:center;font:1rem/1.5 system-ui';
  help.textContent = hint;
  download.href = url.href;
  download.download = filename;
  download.textContent = '↓ PNG';
  download.style.cssText = 'display:inline-block;padding:14px 24px;color:#a44b12;font-weight:600';
  close.textContent = closeLabel;
  close.style.cssText = 'min-height:48px;padding:0 24px;font:inherit';
  close.onclick = () => dialog.close();
  dialog.append(help, image, download, close);
  dialog.addEventListener('close', () => dialog.remove(), { once: true });
  document.body.append(dialog);
  try {
    dialog.showModal();
  } catch (error) {
    dialog.remove();
    throw error;
  }
};
