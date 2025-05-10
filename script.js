function resizeWidget() {
    const inner = document.querySelector('.widget-zoom-inner');
    if (!inner) return;
  
    const baseWidth = 400;
    const baseHeight = 600;
    const screenRatio = window.innerWidth / window.innerHeight;
    const widgetRatio = baseWidth / baseHeight;
  
    let scale;
    if (screenRatio > widgetRatio) {
      // 画面の方が横に広い：高さ基準でフィットさせる
      scale = window.innerHeight / baseHeight;
    } else {
      // 画面の方が縦に広い：横幅基準でフィットさせる
      scale = window.innerWidth / baseWidth;
    }
  
    inner.style.transform = `scale(${scale})`;
  
    // 無駄な空白が出ないよう中央揃え
    inner.style.left = `${(window.innerWidth - baseWidth * scale) / 2}px`;
    inner.style.top = `${(window.innerHeight - baseHeight * scale) / 2}px`;
  }
  
  window.addEventListener('resize', resizeWidget);
  window.addEventListener('load', () => {
    setTimeout(resizeWidget, 500);
  });
  