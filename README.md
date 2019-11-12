# Kustomized Namespaces

Provide management of infinite namespaced feature branch deployments to a Kubernetes cluster via Kustomize. This is designed to read from a GitHub repository containing your manifests, structured as such ([example](https://github.com/dudo/k8s_colors)):

    .
    ├── blue/
    │   ├── base/
    │   │   ├── kustomization.yaml
    │   │   ├── deployment.yaml
    │   │   ├── service.yaml
    │   │   └── etc...yaml
    │   └── overlays/ # this folder will be created **and managed** for you
    │       ├── development/
    │       │   └── kustomization.yaml
    │       ├── feature-branch-1/
    │       │   └── kustomization.yaml
    │       └── feature-branch-2/
    │           └── kustomization.yaml
    └── red/
        ├── base/
        │   ├── kustomization.yaml
        │   ├── deployment.yaml
        │   ├── service.yaml
        │   └── etc...yaml
        └── overlays/ # this folder will be created **and managed** for you
            ├── development/
            │   └── kustomization.yaml
            ├── feature-branch-1/
            │   └── kustomization.yaml
            └── feature-branch-2/
                └── kustomization.yaml

You only need to tell Kustomize about the files in your base folder, [per kustomize](https://github.com/kubernetes-sigs/kustomize), the rest is managed for you.
Within each services’ base folder, create an appropriate `kustomization.yaml`

    ---
    kind: Kustomization
    apiVersion: kustomize.config.k8s.io/v1beta1

    resources:
    - deployment.yaml
    - service.yaml
    - etc...yaml

## Cleanup

This simply removes all overlays in the given namespace.

### Flags

- `-r, --cluster-repo` - GitHub repository that controls your cluster
- `-n, --namespace` - desired namespace, or inferred from $GITHUB_REF
- `-T, --token` -  GitHub access token with repos access, _NOT_ $GITHUB_TOKEN
- `--dry-run` - the yaml files are printed to stdout
- `--flux` - a manifest is generated to allow [Weave Flux](https://github.com/weaveworks/flux) to deploy your cluster

### Demo

    docker build -t kustomized_namespaces/cleanup:latest .
    docker run kustomized_namespaces/cleanup:latest -r dudo/k8s_colors -n feature_branch_1 --dry-run

Really, you'd only see a file change here if you were using `--flux` and had already created the namespace, since we'd be modifying the generators. Otherwise this has no manifests to output.

### Example GitHub Actions Workflow

    on:
      pull_request:
        types: [unlabeled] # or closed, but you'll need to remove the conditional in tear_down
    name: Clean up
    env:
      CLUSTER_REPO: dudo/k8s_colors
    jobs:
      tear_down:
        if: github.event.label.name == 'deploy'
        name: Tear down feature branch
        runs-on: ubuntu-latest
        steps:
        - name: Kustomized Namespace - Cleanup Overlay
          env:
            TOKEN: ${{ secrets.TOKEN }}
          uses: zyngl/cleanup_kustomized_namespace@v1.1.0
          with:
            args: --flux
