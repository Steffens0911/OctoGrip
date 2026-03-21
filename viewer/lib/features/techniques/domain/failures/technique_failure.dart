import 'package:equatable/equatable.dart';

/// Erros de domínio do módulo de técnicas (mapeados para UI / logs).
/// Mantemos hierarquia simples para `Either` sem depender de exceções nas camadas externas.
abstract class TechniqueFailure extends Equatable {
  const TechniqueFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Falha de rede, timeout ou HTTP não OK.
class NetworkTechniqueFailure extends TechniqueFailure {
  const NetworkTechniqueFailure(super.message);
}

/// Nome vazio, slug inválido, etc.
class ValidationTechniqueFailure extends TechniqueFailure {
  const ValidationTechniqueFailure(super.message);
}

/// Cache corrompido ou erro inesperado.
class CacheTechniqueFailure extends TechniqueFailure {
  const CacheTechniqueFailure(super.message);
}

class UnknownTechniqueFailure extends TechniqueFailure {
  const UnknownTechniqueFailure(super.message);
}
