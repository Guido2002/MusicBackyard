/// Every URL is checked before opening a connection, including redirect targets.
class UpdateUrlPolicy {
  const UpdateUrlPolicy({required this.downloadHosts, this.githubRepository});
  final Set<String> downloadHosts;
  final String? githubRepository;
  bool secure(Uri url) =>
      url.scheme == 'https' &&
      url.host.isNotEmpty &&
      url.port == 443 &&
      url.userInfo.isEmpty &&
      url.fragment.isEmpty;
  bool allowsDownload(Uri url) {
    if (!secure(url) ||
        !downloadHosts.contains(url.host.toLowerCase()) ||
        !url.path.toLowerCase().endsWith('.apk')) {
      return false;
    }
    if (url.host == 'github.com') {
      return githubRepository != null &&
          url.path.startsWith('/$githubRepository/releases/download/') &&
          !url.pathSegments.contains('..');
    }
    return true;
  }

  bool allowsRedirect(Uri origin, Uri destination) {
    if (!secure(destination)) {
      return false;
    }
    // GitHub release downloads use short-lived signed URLs on this exact CDN.
    // Custom HTTPS hosts retain the stricter no-redirect policy.
    final repo = githubRepository;
    return repo != null &&
        origin.host == 'github.com' &&
        origin.path.startsWith('/$repo/releases/download/') &&
        destination.host == 'release-assets.githubusercontent.com';
  }
}
