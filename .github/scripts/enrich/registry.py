from .providers import atuin, bjw_helm, cloudflared, kubernetes, qbittorrent, spegel
from .special_class import Provider

PROVIDERS: dict[str, Provider] = {
    "cloudflare/cloudflared": cloudflared.provider,
    "spegel-org/spegel": spegel.provider,
    "qbittorrent/qbittorrent": qbittorrent.provider,
    "home-operations/qbittorrent-libtorrentv1": qbittorrent.provider,
    "bjw-s-labs/helm-charts": bjw_helm.provider,
    "bjw-s-labs/common": bjw_helm.provider,
    "kubernetes/kubernetes": kubernetes.provider,
    "siderolabs/kubelet": kubernetes.provider,
    "atuinsh/atuin": atuin.provider,
}
