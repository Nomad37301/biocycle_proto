import 'package:biocycle_proto/features/demo_session/domain/demo_session.dart';
import 'package:biocycle_proto/features/partners/domain/partner_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool allows(RequestStatus current, RequestStatus next, DemoRole actor) {
    return RequestTransitionPolicy.allows(
      current: current,
      next: next,
      actor: actor,
      sender: DemoRole.operator,
      receiver: DemoRole.supplier,
      completer: DemoRole.operator,
    );
  }

  test('penerima dapat menerima atau menolak pengajuan menunggu', () {
    expect(
      allows(RequestStatus.pending, RequestStatus.accepted, DemoRole.supplier),
      isTrue,
    );
    expect(
      allows(RequestStatus.pending, RequestStatus.rejected, DemoRole.supplier),
      isTrue,
    );
    expect(
      allows(RequestStatus.pending, RequestStatus.accepted, DemoRole.operator),
      isFalse,
    );
  });

  test('pengirim dapat membatalkan dan menyelesaikan setelah diterima', () {
    expect(
      allows(RequestStatus.pending, RequestStatus.cancelled, DemoRole.operator),
      isTrue,
    );
    expect(
      allows(
        RequestStatus.accepted,
        RequestStatus.completed,
        DemoRole.operator,
      ),
      isTrue,
    );
    expect(
      allows(
        RequestStatus.accepted,
        RequestStatus.completed,
        DemoRole.supplier,
      ),
      isFalse,
    );
  });

  test('status akhir tidak dapat diubah kembali', () {
    expect(
      allows(RequestStatus.completed, RequestStatus.pending, DemoRole.operator),
      isFalse,
    );
    expect(
      allows(RequestStatus.rejected, RequestStatus.accepted, DemoRole.supplier),
      isFalse,
    );
  });

  test('penerima barang dapat menyelesaikan respons kebutuhan pembeli', () {
    expect(
      RequestTransitionPolicy.allows(
        current: RequestStatus.accepted,
        next: RequestStatus.completed,
        actor: DemoRole.buyer,
        sender: DemoRole.operator,
        receiver: DemoRole.buyer,
        completer: DemoRole.buyer,
      ),
      isTrue,
    );
  });
}
