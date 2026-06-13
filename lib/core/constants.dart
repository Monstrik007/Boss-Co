/// Константы сети и игры.
class GameConstants {
  static const serviceType = '_bossgame._tcp';
  static const serviceName = 'BossVsSlaves';
  static const port = 45678;
  static const salaryAmount = 5000;
  static const defaultFineAmount = 500;
  static const maxPlayers = 6;
  static const maxRankLevel = 3;
}

enum PlayerRole { boss, subordinate }

enum GamePhase { lobby, playing, finished }

enum MessageType {
  join,
  joinAck,
  state,
  startGame,
  paySalary,
  rejoin,
  assignTask,
  completeTask,
  resolveTask,
  promotePlayer,
  fine,
  buyItem,
  prank,
  chat,
  officePhoto,
  officePhotoPatch,
  officePhotoReaction,
  officePhotoComment,
  prankEffect,
  error,
}

enum TaskStatus { none, active, awaitingBoss, refused }

enum BossTaskDecision { pay, skip, fine }
