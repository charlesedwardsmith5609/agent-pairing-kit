# Sandboxed devcontainer

This page is documentation only. The kit does not ship a `devcontainer.json`.

An agent process on the host can read the host filesystem, the host credential store, and a mounted Docker socket. A devcontainer is a separate workspace for that process.

- Run the agent inside a devcontainer, not on the host account that holds production credentials.
- Do not mount the host Docker socket into the container. That mount gives the container control of the host.
- Do not copy cloud credentials, SSH keys, or `.env` files into the image or into a mount.
- Mount only the repository the task is working on.
- Throw the container away when the task is done.

needs verification: the exact `devcontainer.json` fields for a non-root user, a read-only root filesystem, and dropped capabilities. Those fields change across the Dev Containers spec. Confirm them in the spec you use before treating a template as a boundary.
