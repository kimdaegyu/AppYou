// Look At You 카카오 앱의 JavaScript 키.
// 값이 있으면 페이지를 열 때 Kakao.init을 한 번 호출한다.
var lookAtYouKakaoJavaScriptKey = '66afcf1c82114e5b0de4e624f3ebdb43';

(function () {
  var key = lookAtYouKakaoJavaScriptKey;
  if (!window.Kakao || typeof key !== 'string' || key.length === 0) {
    return;
  }
  if (!Kakao.isInitialized()) {
    Kakao.init(key);
  }
})();

// 업로드 직후 사용자 동작이 남아 있는지. 없으면 공유창을 열지 않는다.
function lookAtYouKakaoGestureActive() {
  var activation = navigator.userActivation;
  if (!activation || typeof activation.isActive !== 'boolean') {
    return true;
  }
  return activation.isActive;
}

// PNG 바이트를 카카오 이미지로 올리고 원본 주소와 크기를 돌려준다.
function lookAtYouUploadKakaoImage(bytes, filename) {
  var file = new File([bytes], filename, { type: 'image/png' });
  var transfer = new DataTransfer();
  transfer.items.add(file);
  return Kakao.Share.uploadImage({ file: transfer.files }).then(function (response) {
    var image = response && response.infos && response.infos.original;
    if (!image || typeof image.url !== 'string' || image.url.length === 0) {
      throw new Error('missing kakao image');
    }
    return {
      url: image.url,
      width: Number(image.width),
      height: Number(image.height)
    };
  });
}

function lookAtYouSendKakaoFeed(settings) {
  try {
    Kakao.Share.sendDefault(settings);
    return 'opened';
  } catch (error) {
    return 'failed';
  }
}
