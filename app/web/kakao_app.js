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
