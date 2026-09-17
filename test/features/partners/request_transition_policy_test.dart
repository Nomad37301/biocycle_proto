import 'package:biocycle_proto/features/partners/domain/partner_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool allows(RequestStatus current, RequestStatus next, int actorId) {
    return RequestTransitionPolicy.allows(
      current: current,
      next: next,
      actorId: actorId,
      senderId: 3,
      receiverId: 1,
      completionId: 3,
    );
  }

  test('penerima dapat menerima atau menolak pengajuan menunggu', () {
    expect(allows(RequestStatus.pending, RequestStatus.accepted, 1), isTrue);
    expect(allows(RequestStatus.pending, RequestStatus.rejected, 1), isTrue);
    expect(allows(RequestStatus.pending, RequestStatus.accepted, 3), isFalse);
  });

  test('pengirim dapat membatalkan dan menyelesaikan setelah diterima', () {
    expect(allows(RequestStatus.pending, RequestStatus.cancelled, 3), isTrue);
    expect(allows(RequestStatus.accepted, RequestStatus.completed, 3), isTrue);
    expect(allows(RequestStatus.accepted, RequestStatus.completed, 1), isFalse);
  });

  test('status akhir tidak dapat diubah kembali', () {
    expect(allows(RequestStatus.completed, RequestStatus.pending, 3), isFalse);
    expect(allows(RequestStatus.rejected, RequestStatus.accepted, 1), isFalse);
  });

  test('penerima barang dapat menyelesaikan respons kebutuhan pembeli', () {
    expect(
      RequestTransitionPolicy.allows(
        current: RequestStatus.accepted,
        next: RequestStatus.completed,
        actorId: 4,
        senderId: 3,
        receiverId: 4,
        completionId: 4,
      ),
      isTrue,
    );
  });
}
