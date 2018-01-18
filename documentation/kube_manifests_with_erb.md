# Writing Kubernetes manifests with ERB

## kubernetes/ directory
All .yaml and .yaml.erb files in `kubernetes/` are templated out into the
`build/kubernetes/` directory with `bundle exec kdt render_deploys`.

Kubernetes manifests can be in subdirectories of any depth in the
`kubernetes/` directory for organization purposes.

## Examples

Examples of `kubernetes/` directories with .yaml and .yaml.erb files are
[arbortech/workspace](https://git.***REMOVED***/arbortech/workspace),
[kube-infra](https://git.***REMOVED***/OpsRepos/kube-infra), and
[k8s-reaper](https://git.***REMOVED***/OpsRepos/k8s-reaper).

## ERB variables

The ERB templates are rendered using context variables from your project's
deploy.yml and are available in ERB in the `config` variable, for example in
`<%= config['environment'] %>`.

By default, the following context variables are available.

```
config['username']                  # your username
config['tag']                       # the git tag
config['cloud']                     # the Kubernetes cluster's cloud e.g. colo, aws, local (minikube), gcp
config['target']                    # the Kubernetes cluster target name e.g. colo-service, us-east-1, eu-west-1
config['kubernetes_major_version']  # the Kubernetes cluster's major version e.g. 1
config['kubernetes_minor_version']  # the Kubernetes cluster's major version e.g. 7
config['image_registry']            # the Kubernetes cluster's Docker image registry e.g. AWS ECR, GCP GCR, "local-registry" (none)
config['image_tag']                 # Docker tag used for all images
config['pull_policy']               # the default image pull policy for Kubernetes container templates
```

Extra flags can be provided by configuring your deploy.yml's `extra_flags`.

```
deploy:
  clusters:
    - target: local
      environment: staging
      extra_flags:
        cloud_fs: /etc/data/
        image_tag: latest
    - target: colo-service
      environment: prod
      extra_flags:
        cloud_fs: s3://
  flavors:
    default: {}
```

As you can see above with `image_tag`, the default variables above can be
overriden. See [examples/projects/deploy.yml](../examples/project/deploy.yml).

## A word on container image registry, tag, and pull policy

As described above, the image registry, tag, and pull policy are available as
context variables. As a best practice, any Docker containers you build
should be templated out in your workloads like so:

```yaml
      containers:
        - image: <%= config["image_registry"] %>/fluentd:<%= config["image_tag"] %>
          imagePullPolicy: <%= config["pull_policy"] %>
```

The `image_tag` made available with `bundle exec kdt render_deploys`
is the same image tag used to tag and push Docker images in
`bundle exec kdt publish_container`.

Both of these commands are intended to be used together.

The `image_tag` is a unique identifier used to ensure we know what image is
being used in production. The `image_tag` is built from the commit and the
caller i.e. either your username or the Jenkins project build name, such
that it's clear where the image came from.

For local stacks, we recommend using `image_tag: latest` in your
deploy.yml for convenience only.

Similarly, `image_registry` is used by both `bundle exec kdt render_deploys`
and `bundle exec kdt publish_container`, so it's important to template this out
as well.

## Using render_deploys

`bundle exec kdt render_deploys` should be called in your Jenkins build,
as described in [documentation/deploy.md](deploy.md).

This renders all Kubernetes plain YAMLs and ERB templates, and bundles them into
deploy artifacts.

You'll in general be using `bundle exec kdt render_deploys` in the following
circumstances:
- to test your ERB templates;
- to release to your local Minikube cluster.

Otherwise for live staging or production releases, you'll rely on the deploy
artifacts rendered and pushed by Jenkins, unless you're doing a manual release,
which would require re-tagging and re-pushing Docker images.

See [documentation/deploy.md](deploy.md) for more.
