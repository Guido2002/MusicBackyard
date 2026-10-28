enum UpdateStatus {
  unconfigured,
  idle,
  checking,
  upToDate,
  available,
  downloading,
  interrupted,
  downloaded,
  preparing,
  installStarted,
  permissionRequired,
  error,
}

class UpdateStateMachine {
  UpdateStatus status = UpdateStatus.idle;
  void reset() {
    status = UpdateStatus.idle;
  }

  static const transitions = <UpdateStatus, Set<UpdateStatus>>{
    UpdateStatus.idle: {UpdateStatus.unconfigured, UpdateStatus.checking},
    UpdateStatus.unconfigured: {
      UpdateStatus.checking,
      UpdateStatus.unconfigured,
    },
    UpdateStatus.checking: {
      UpdateStatus.upToDate,
      UpdateStatus.available,
      UpdateStatus.error,
      UpdateStatus.unconfigured,
    },
    UpdateStatus.upToDate: {UpdateStatus.checking},
    UpdateStatus.available: {
      UpdateStatus.checking,
      UpdateStatus.downloading,
      UpdateStatus.preparing,
      UpdateStatus.downloaded,
    },
    UpdateStatus.downloading: {
      UpdateStatus.downloaded,
      UpdateStatus.interrupted,
      UpdateStatus.error,
    },
    UpdateStatus.interrupted: {UpdateStatus.downloading, UpdateStatus.checking},
    UpdateStatus.downloaded: {UpdateStatus.preparing, UpdateStatus.checking},
    UpdateStatus.preparing: {
      UpdateStatus.installStarted,
      UpdateStatus.permissionRequired,
      UpdateStatus.error,
      UpdateStatus.available,
    },
    UpdateStatus.permissionRequired: {
      UpdateStatus.preparing,
      UpdateStatus.checking,
    },
    UpdateStatus.installStarted: {
      UpdateStatus.downloaded,
      UpdateStatus.checking,
    },
    UpdateStatus.error: {UpdateStatus.checking, UpdateStatus.downloading},
  };
  void move(UpdateStatus next) {
    if (!transitions[status]!.contains(next)) {
      throw StateError('Invalid update transition: $status -> $next');
    }
    status = next;
  }
}
