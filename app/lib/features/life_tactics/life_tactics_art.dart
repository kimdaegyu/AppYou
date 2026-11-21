/// 승인된 축구장·전술판·마커·공유 카드와 결과별 사이다 파일.
///
/// 채점과 분리된 화면 매핑이다. 전술판은 v002다. tr06·tr10은 D.C 로고 v003, 나머지 8종은 v002.
abstract final class LifeTacticsArt {
  static const stadium = 'assets/images/life_tactics/stadium_v001.webp';
  static const tacticsBoard =
      'assets/images/life_tactics/tactics_board_v002.webp';
  static const marker = 'assets/images/life_tactics/jersey_marker_v001.webp';
  static const shareTemplate =
      'assets/images/life_tactics/share_template_v001.png';
  static const coach = 'assets/images/saida/saida_football_coach_v001.webp';
  static const baseSmile = 'assets/images/saida/saida_base_smile_v001.webp';
  static const wink = 'assets/images/saida/saida_wink_v001.png';

  static const v003Results = {'tr06', 'tr10'};

  /// 유니폼 마커의 한 변. 전술판 폭의 9%를 1.5배 한 값이다.
  static const markerWidthFactor = 0.135;

  /// 전술판 안쪽 잔디의 위·아래 여백. 세 줄 라벨이 이 기준으로 맞는다.
  static const boardInsetTop = 0.08;
  static const boardInsetBottom = 0.093;

  /// 1080 시안. 사이다와 전술판 사이에 성향 라벨이 들어갈 자리를 둔다.
  static const shareFrame = 1080.0;
  static const shareSaidaBox = ShareSaidaBox(
    left: 60 / shareFrame,
    top: 215 / shareFrame,
    size: 440 / shareFrame,
  );
  static const shareLabelLeft = 488 / shareFrame;
  static const shareLabelWidth = 180 / shareFrame;
  static const shareBoardLeft = 680 / shareFrame;
  static const shareBoardTop = 220 / shareFrame;
  static const shareBoardWidth = 344 / shareFrame;
  static const shareBoardHeight = 430 / shareFrame;

  /// 템플릿에 박힌 경기장을 가리는 크림색 영역. 테두리와 제목은 건드리지 않는다.
  static const shareStadiumMaskLeft = 48 / shareFrame;
  static const shareStadiumMaskTop = 120 / shareFrame;
  static const shareStadiumMaskWidth = 980 / shareFrame;
  static const shareStadiumMaskHeight = 510 / shareFrame;

  /// 사이다·라벨·전술판이 있는 밴드. 경기장 사진과 블러가 같은 사각형이다.
  static const shareBlurLeft = 36 / shareFrame;
  static const shareBlurTop = 168 / shareFrame;
  static const shareBlurWidth = 1008 / shareFrame;
  static const shareBlurHeight = 492 / shareFrame;

  /// 공격·중원·수비 줄의 세로 중심. 전술판 높이를 1로 둔 값이다.
  static List<double> lineCenters(double height) {
    final inner = height * (1 - boardInsetTop - boardInsetBottom);
    final row = inner / 3;
    return [
      for (var index = 0; index < 3; index++)
        height * boardInsetTop + row * (index + 0.5),
    ];
  }

  /// 포메이션 문자열의 수비·중원·공격 인원. 형식이 아니면 null이다.
  static List<int>? lineCounts(String formation) {
    final visual = markerRows(formation);
    if (visual.length != 3) {
      return null;
    }
    return [visual[2], visual[1], visual[0]];
  }

  /// 결과 ID에 대응하는 사이다. 모르는 ID는 빈 문자열이라 이미지를 만들지 않는다.
  static String saidaAsset(String resultTypeId) {
    if (!_known.contains(resultTypeId)) {
      return '';
    }
    final version = v003Results.contains(resultTypeId) ? 'v003' : 'v002';
    return 'assets/images/saida/saida_life_tactics_${resultTypeId}_$version.webp';
  }

  /// 포메이션 문자열은 수비-중원-공격이다. 화면은 위에서 공격, 중원, 수비 순이다.
  ///
  /// 마커 수는 점수 크기가 아니라 포메이션 숫자다. 형식이 아니면 빈 목록이다.
  static List<int> markerRows(String formation) {
    final parts = formation.split('-');
    if (parts.length != 3) {
      return const [];
    }
    final numbers = <int>[];
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0) {
        return const [];
      }
      numbers.add(value);
    }
    return [numbers[2], numbers[1], numbers[0]];
  }

  static const _known = {
    'tr01',
    'tr02',
    'tr03',
    'tr04',
    'tr05',
    'tr06',
    'tr07',
    'tr08',
    'tr09',
    'tr10',
  };
}

/// 공유 카드 한 변을 1로 둔 사이다 정사각 영역.
class ShareSaidaBox {
  const ShareSaidaBox({
    required this.left,
    required this.top,
    required this.size,
  });

  final double left;
  final double top;
  final double size;
}
