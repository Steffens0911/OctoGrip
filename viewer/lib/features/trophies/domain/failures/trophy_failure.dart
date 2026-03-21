import 'package:equatable/equatable.dart';

abstract class TrophyFailure extends Equatable {
  const TrophyFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class NetworkTrophyFailure extends TrophyFailure {
  const NetworkTrophyFailure(super.message);
}

class ValidationTrophyFailure extends TrophyFailure {
  const ValidationTrophyFailure(super.message);
}

class CacheTrophyFailure extends TrophyFailure {
  const CacheTrophyFailure(super.message);
}

class UnknownTrophyFailure extends TrophyFailure {
  const UnknownTrophyFailure(super.message);
}
