import 'dart:io';

import 'package:biocycle_proto/core/database/app_database.dart';
import 'package:biocycle_proto/features/partners/data/local_partner_repository.dart';
import 'package:biocycle_proto/features/partners/domain/partner_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('fixture completed dan penerimaan 250 dari 500 konsisten', () async {
    final directory = await Directory.systemTemp.createTemp('biocycle_pitch_');
    final path = p.join(directory.path, 'pitch.db');
    final database = await AppDatabase.open(dbPath: path);
    final repository = LocalPartnerRepository(database);

    final flow = await repository.getNetworkFlow();
    expect(flow.wasteInKg, 120);
    expect(flow.outputKg, 60);
    expect(flow.monitoredUnits, 3);

    await repository.transitionRequest(
      id: 1001,
      next: RequestStatus.accepted,
      actorId: 1,
      acceptedQuantityKg: 250,
    );

    final request = (await repository.getRequest(1001))!;
    final listing = (await repository.getListing(101))!;
    final history = await repository.getRequestHistory(1001);
    expect(request.initialQuantityKg, 500);
    expect(request.acceptedQuantityKg, 250);
    expect(listing.availableKg, 250);
    expect(history.map((entry) => entry.status), [
      RequestStatus.pending,
      RequestStatus.accepted,
    ]);

    await database.database.insert('partners', {
      'id': 5,
      'name': 'Operator Fixture Kedua',
      'role': 'operator',
      'region': 'Badung',
    });
    await database.database.insert('requests', {
      'id': 1005,
      'listing_id': 101,
      'sender_id': 5,
      'receiver_id': 1,
      'completion_id': 5,
      'sender_role': 'operator',
      'receiver_role': 'supplier',
      'sender_name': 'Operator Fixture Kedua',
      'receiver_name': 'Pasar Organik Jimbaran',
      'summary': 'Permintaan bersaing',
      'quantity_kg': 300.0,
      'initial_quantity_kg': 300.0,
      'accepted_quantity_kg': null,
      'history_limited': 0,
      'note': '',
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    await expectLater(
      () => repository.transitionRequest(
        id: 1005,
        next: RequestStatus.accepted,
        actorId: 1,
        acceptedQuantityKg: 300,
      ),
      throwsStateError,
    );

    await database.database.close();
    await directory.delete(recursive: true);
  });
}
