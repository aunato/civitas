import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../auth/domain/entities/user_entity.dart';
import '../models/trusted_contact_model.dart';
import '../models/trust_request_model.dart';

abstract class NetworkRemoteDataSource {
  Future<List<TrustedContactModel>> getTrustedContacts(String userUid);
  Future<void> addTrustedContact(String userUid, TrustedContactModel contact);
  Future<void> removeTrustedContact(String userUid, String contactId);
  Future<List<TrustRequestModel>> getPendingTrustRequests(String userPhone);
  Future<TrustRequestModel> sendTrustRequest(TrustRequestModel request);
  Future<void> respondTrustRequest({
    required String requestId,
    required bool accept,
    required UserEntity respondingUser,
  });
}

class NetworkRemoteDataSourceImpl implements NetworkRemoteDataSource {
  final FirebaseFirestore _firestore;

  // Respaldo en memoria para testing y modo offline
  static final Map<String, List<TrustedContactModel>> _inMemoryContacts = {};
  static final List<TrustRequestModel> _inMemoryRequests = [];

  NetworkRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<TrustedContactModel>> getTrustedContacts(String userUid) async {
    try {
      final snapshot = await _firestore
          .collection('usuarios')
          .doc(userUid)
          .collection('red_confianza')
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((doc) => TrustedContactModel.fromFirestore(doc))
            .toList();
      }

      // Si Firestore no tiene datos o estamos en demo/test
      return _inMemoryContacts[userUid] ?? [];
    } catch (e) {
      debugPrint('[NetworkRemoteDataSource] getTrustedContacts fallback: $e');
      return _inMemoryContacts[userUid] ?? [];
    }
  }

  @override
  Future<void> addTrustedContact(String userUid, TrustedContactModel contact) async {
    try {
      await _firestore
          .collection('usuarios')
          .doc(userUid)
          .collection('red_confianza')
          .doc(contact.id.isNotEmpty ? contact.id : null)
          .set(contact.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[NetworkRemoteDataSource] addTrustedContact fallback: $e');
    }

    final current = _inMemoryContacts[userUid] ?? [];
    current.removeWhere((c) => c.id == contact.id || c.phone == contact.phone);
    current.add(contact);
    _inMemoryContacts[userUid] = current;
  }

  @override
  Future<void> removeTrustedContact(String userUid, String contactId) async {
    try {
      await _firestore
          .collection('usuarios')
          .doc(userUid)
          .collection('red_confianza')
          .doc(contactId)
          .delete();
    } catch (e) {
      debugPrint('[NetworkRemoteDataSource] removeTrustedContact fallback: $e');
    }

    final current = _inMemoryContacts[userUid] ?? [];
    current.removeWhere((c) => c.id == contactId);
    _inMemoryContacts[userUid] = current;
  }

  @override
  Future<List<TrustRequestModel>> getPendingTrustRequests(String userPhone) async {
    final cleanPhone = userPhone.replaceAll(' ', '').replaceAll('-', '');
    try {
      final snapshot = await _firestore
          .collection('solicitudes_confianza')
          .where('to_phone', isEqualTo: cleanPhone)
          .where('status', isEqualTo: 'PENDING')
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((doc) => TrustRequestModel.fromFirestore(doc))
            .toList();
      }

      return _inMemoryRequests
          .where((r) => (r.toPhone == cleanPhone || r.toPhone == userPhone) && r.isPending)
          .toList();
    } catch (e) {
      debugPrint('[NetworkRemoteDataSource] getPendingTrustRequests fallback: $e');
      return _inMemoryRequests
          .where((r) => (r.toPhone == cleanPhone || r.toPhone == userPhone) && r.isPending)
          .toList();
    }
  }

  @override
  Future<TrustRequestModel> sendTrustRequest(TrustRequestModel request) async {
    try {
      final docRef = _firestore.collection('solicitudes_confianza').doc();
      final finalModel = TrustRequestModel(
        id: docRef.id,
        fromUid: request.fromUid,
        fromName: request.fromName,
        fromPhone: request.fromPhone,
        fromRut: request.fromRut,
        fromRol: request.fromRol,
        fromReputacion: request.fromReputacion,
        fromCredencialFolio: request.fromCredencialFolio,
        toPhone: request.toPhone,
        toUid: request.toUid,
        status: 'PENDING',
        createdAt: request.createdAt,
      );

      await docRef.set(finalModel.toMap());
      _inMemoryRequests.add(finalModel);
      return finalModel;
    } catch (e) {
      debugPrint('[NetworkRemoteDataSource] sendTrustRequest fallback: $e');
      _inMemoryRequests.add(request);
      return request;
    }
  }

  @override
  Future<void> respondTrustRequest({
    required String requestId,
    required bool accept,
    required UserEntity respondingUser,
  }) async {
    final status = accept ? 'ACCEPTED' : 'REJECTED';
    final now = DateTime.now();

    // Actualizar solicitud en memoria
    final index = _inMemoryRequests.indexWhere((r) => r.id == requestId);
    TrustRequestModel? req;
    if (index != -1) {
      req = _inMemoryRequests[index].copyWith(
        status: status,
        toUid: respondingUser.uid,
        respondedAt: now,
      ) as TrustRequestModel;
      _inMemoryRequests[index] = req;
    }

    try {
      final docRef = _firestore.collection('solicitudes_confianza').doc(requestId);
      await docRef.update({
        'status': status,
        'to_uid': respondingUser.uid,
        'responded_at': Timestamp.fromDate(now),
      });

      if (accept) {
        final docSnap = await docRef.get();
        if (docSnap.exists) {
          req = TrustRequestModel.fromFirestore(docSnap);
        }
      }
    } catch (e) {
      debugPrint('[NetworkRemoteDataSource] respondTrustRequest update fallback: $e');
    }

    if (accept && req != null) {
      // Agregar recíprocamente a ambas redes de confianza
      final contactForRespondingUser = TrustedContactModel(
        id: req.fromUid,
        name: req.fromName,
        phone: req.fromPhone,
        civitasUid: req.fromUid,
        isVerified: true,
        relationship: 'Red CIVITAS Verificada',
        addedAt: now,
      );

      final contactForRequester = TrustedContactModel(
        id: respondingUser.uid,
        name: respondingUser.nombre,
        phone: respondingUser.telefono,
        civitasUid: respondingUser.uid,
        isVerified: true,
        relationship: 'Red CIVITAS Verificada',
        addedAt: now,
      );

      await addTrustedContact(respondingUser.uid, contactForRespondingUser);
      await addTrustedContact(req.fromUid, contactForRequester);
    }
  }
}
