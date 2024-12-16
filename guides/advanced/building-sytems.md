# Building Nerves Systems with the `nerves_systems` Repository

This guide provides instructions for building custom Nerves systems using the [`nerves_systems`](https://github.com/nerves-project/nerves_systems) repository.

The `nerves_systems` repository offers an alternative way to build Nerves systems, designed for scenarios where the standard `mix`-based approach may be slower, such as when working extensively with Buildroot or maintaining multiple systems. While this method is faster and more efficient, it requires some setup and familiarity with system configuration and build processes.

By following this guide, you’ll gain the ability to create and customize Nerves systems for your hardware platform, contributing valuable improvements to the Nerves community.

---

## Prerequisites

The `nerves_systems` build process only works on **Linux** systems with `x86_64` or `aarch64` architectures. Non-Linux users must set up a Linux environment, such as a virtual machine (VM) or a container.

### General Requirements

- Basic familiarity with the Nerves project and embedded systems development.
- Access to a Linux environment:
  - **Native Linux Machine**: Best for performance and simplicity.
  - **macOS Users**: Install a Linux VM (e.g., via [UTM](https://mac.getutm.app)) to create an Ubuntu environment.
  - **Windows Users**: Use [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) with an Ubuntu distribution.
- At least **128GB of free disk space**: Building Nerves systems can require significant disk space, depending on the components included in the system.

### Linux Environment Requirements

Install the following packages in your Linux environment:

<!-- tabs-open -->
#### Apt based distributions (Ubuntu, Debian...)
```bash
sudo apt update && sudo apt install -y git build-essential bc cmake cvs wget curl mercurial python3 python3-aiohttp python3-flake8 python3-ijson python3-nose2 python3-pexpect python3-pip python3-requests rsync subversion unzip gawk jq squashfs-tools libssl-dev automake autoconf libncurses5-dev
```

#### Arch linux
```bash
sudo pacman -Syu git base-devel bc cmake cvs wget curl mercurial python python-aiohttp flake8 python-ijson python-nose2 python-pexpect python-pip python-requests rsync subversion unzip gawk jq squashfs-tools openssl automake autoconf ncurses
```

#### RPM based distributions (Red Hat, Fedora...)
```bash
sudo dnf install -y git @development-tools @c-development kernel-devel cvs wget curl mercurial python3 python3-aiohttp python3-flake8 python3-ijson python3-nose2 python3-pexpect python3-pip python3-requests rsync  unzip gawk jq squashfs-tools openssl-devel ncurses-devel
```
<!-- tabs-close -->

> #### Why These Packages? {: .info}
>
> These packages provide essential tools and libraries required for the Buildroot environment and system customization.


### macOS Setup

- Install [UTM](https://mac.getutm.app) to set up a Linux VM.
- Follow the Linux Environment Requirements above inside the VM.

### Windows Setup

- Install [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install).
- Set up an Ubuntu distribution and follow the Linux Environment Requirements above within WSL2.

### Install Erlang and Elixir

If you've already followed the [Nerves Installation guide](https://hexdocs.pm/nerves/installation.html), Erlang and Elixir should be installed on your system. If not, refer to the installation instructions provided in the guide for your operating system.

### Install Nerves Archives

If you've completed the [Nerves Installation guide](https://hexdocs.pm/nerves/installation.html), the Nerves bootstrap archive and local rebar should already be set up. If not, you can install them with:

```bash
mix archive.install hex nerves_bootstrap
mix local.rebar
```

### Cloning the `nerves_systems` Repository

To begin working with Nerves systems, you’ll need to clone the `nerves_systems` repository from GitHub. This repository contains the necessary scripts and configurations for building and maintaining custom Nerves systems.

```bash
  git clone https://github.com/nerves-project/nerves_systems.git
  cd nerves_systems
```

---

## Step 1: Configuring the Build Environment

### Copy the Starter Configuration

To begin configuring the environment for building Nerves systems, you need to create a configuration file. This file specifies which systems to build. Use the provided starter configuration as a template:

```bash
cp config/starter-config.exs config/config.exs
```

The `starter-config.exs` file includes example configurations for common hardware platforms.

### Modify the Configuration File

Open the newly created `config/config.exs` file in a text editor. Review the listed systems and customize the configuration to include only the systems you want to build. For example:

### Download the Necessary Systems

After finalizing the configuration file, use the `ns.clone` mix task to download the repositories for the specified systems into the `src` directory. This command automates the cloning process:

```bash
mix ns.clone
```

The directory structure after running the command will look something like this:

```
src/
    nerves_system_br
    nerves_system_rpi0
    nerves_system_rpi3
    nerves_system_bbb
    ...
```

> #### Tip {: .tip}
>
> If you prefer, you can manually clone individual repositories into the `src` directory using `git clone`. Ensure the directory structure matches the above example.

> #### Resetting the Environment {: .info}
>
> If you need to start over or clean the environment:
>
> - Delete the `src` directory:
>   ```bash
>   rm -rf src
>   ```
> - Adjust your `config/config.exs` file as needed and rerun the `mix ns.clone` task.

---

## Step 2: Building Your Nerves Systems

The `nerves_systems` repository simplifies building custom systems by automating most of the setup. Follow these steps to build your systems:

### 1. Start the Build Process

Run the `ns.build` Mix task to build all systems listed in your configuration file. This task generates Buildroot `.config` files and compiles the systems.

```bash
mix ns.build
```

> #### What Happens During the Build? {: .info}
>
> - `.config` files are generated from `nerves_defconfig`.
> - The Buildroot process compiles the system for each target.

### 2. Check Build Output

Once the build completes, system outputs will be located in the `o/` directory. For example:

```plaintext
o/
  rpi0/
  rpi3/
  bbb/
```

Each directory contains:

- `.config`: The Buildroot configuration file.
- `build/`: Compiled binaries and intermediate files.
- `nerves.env.sh`: Script for setting environment variables.

> #### Quick Verification {: .tip}
>
> Run `ls o/<system name>` to confirm the build output exists (e.g., `ls o/rpi0`).

### 3. Handle Build Failures

If the `ns.build` task fails, use the following steps to debug:

1. **Locate the Failing System**:
   Navigate to the output directory of the system that failed:

   ```bash
   cd o/<system name>
   ```

2. **Rebuild Manually**:
   Run the Buildroot `make` process to identify issues:

   ```bash
   make
   ```

3. **Review Logs**:
   Examine error messages or logs for missing dependencies or configuration issues.

> #### Common Issues {: .warning}
>
> - Missing system dependencies: Ensure all required packages are installed.
> - Insufficient resources: Verify available disk space and memory.
> - Configuration errors: Check the `.config` file for misconfigurations.

### 4. Retry a Clean Build

If issues persist, clean the system's output directory and rebuild:

```bash
rm -rf o/<system name>
mix ns.build
```

> #### Why Clean Builds? {: .info}
>
> Cleaning removes corrupted or incomplete files, ensuring the build starts from a fresh state.

### 5. (Optional) Preload Build Dependencies

To speed up builds, you can preload dependencies for a system by running:

```bash
cd o/<system name>
make source
```

This downloads all required files in advance, making subsequent builds faster.

> #### When to Preload? {: .tip}
>
> - For systems with frequent reconfigurations.
> - When working offline or on slower networks.

---

## Step 3: Using Your Custom Nerves System

After successfully building the Nerves system, you need to set up your environment to use it in your Nerves project. This involves loading environment variables and specifying the target system for your project.

1. **Source the Environment Script**

   Each built system includes a `nerves.env.sh` script in the corresponding output directory (e.g., `o/rpi0/nerves.env.sh`). This script sets the necessary environment variables for your custom-built system.

   Open a new terminal session dedicated to working with your custom-built system, and source the script:

   ```bash
   . ~/path/to/nerves_systems/o/rpi0/nerves.env.sh
   ```

   Replace `rpi0` with the short name of your target system (e.g., `rpi3`, `bbb`) and adjust the path as needed.

   > #### Warning {: .warning}
   >
   > Each time you start a new terminal session for your Nerves project, you must source the script again to ensure the custom-built system is correctly configured.

2. **Set the Target System**
   Nerves uses the `MIX_TARGET` environment variable to identify the hardware target for your project. Set this variable to the short name of your target system. For example:

   ```bash
   export MIX_TARGET=rpi0
   ```

3. **Build Your Nerves Project**
   Navigate to your Nerves project directory and build it using `mix`. The environment variables and target settings will ensure that the project uses your custom-built Nerves system:

   ```bash
   mix deps.get
   mix firmware
   ```

4. **Verify the Custom System is in Use**
   Check that your project is using the custom-built system by running:

   ```bash
   mix nerves.info
   ```

   Look for the output indicating that the system is being sourced from your custom-built location (e.g., `o/rpi0`).

   > #### Troubleshooting {: .tip}
   >
   > - If the custom-built system isn’t being used, double-check that:
   >   - The `nerves.env.sh` script was sourced correctly.
   >   - The `MIX_TARGET` environment variable matches your intended target system.
   > - Verify the `o/<system short name>` directory contains the required build artifacts.

---

## Step 4: Customizing the Build (Optional)

Customizing your Nerves system is an advanced but powerful way to tailor the system to your needs. For comprehensive details on customizing systems, refer to the official [Customizing Your Nerves System](https://hexdocs.pm/nerves/customizing-systems.html) document. This guide provides deeper insights into topics such as Buildroot configurations, kernel adjustments, and integrating additional features.

Customizing the build allows you to tailor the Nerves system to meet specific requirements for your hardware or application. This involves modifying Buildroot configurations and applying changes to the Nerves system.

### Modify Buildroot Package Configuration

Navigate to the output directory of system you wish to modify.

```bash
cd o/<system short name>
```

Workflow for customizing a Nerves system is the same as when using Buildroot outside of Nerves,
using `make menuconfig` and `make savedefconfig`.

The main package configuration workflows are divided into three categories,
depending on what you want to configure:

1. Select base packages by running `make menuconfig`
2. Modify the Linux kernel and kernel modules with `make linux-menuconfig`
3. Enable more command line utilities using `make busybox-menuconfig`

When you quit from the `menuconfig` interface, the changes are stored
temporarily. To save them back to your system source directory, follow the
appropriate steps below:

1. After `make menuconfig`:

    Run `make savedefconfig` to update the `nerves_defconfig` in your System.

2. After `make linux-menuconfig`:

    Once done with configuring the kernel, you can save the Linux config to the
    default configuration file using `make linux-update-defconfig`. The destination
    file is `linux-4.9.defconfig` in your project's root (or whatever the kernel
    version is you're working with).

    > NOTE: If your system doesn't contain a custom Linux configuration yet,
    you'll need to update the Buildroot configuration (using `make menuconfig`)
    to point to the new Linux defconfig in your system directory. The path is
    usually something like `$(NERVES_DEFCONFIG_DIR)/linux-x.y_defconfig`.

3. After `make busybox-menuconfig`:

    Unfortunately, there's not currently an easy way to save a BusyBox defconfig.
    What you have to do instead is save the full BusyBox config and configure it
    to be included in your `nerves_defconfig`.

    ```bash
    cp build/busybox-1.27.2/.config ../src/<full system name>/busybox_defconfig
    ```

    Like the Linux configuration, the Buildroot configuration will need to be
    updated to point to the custom config if it isn't already. This can be done
    via `make menuconfig` and navigating to **Target Packages** and finding the
    **Additional BusyBox configuration fragment files** option under the
    **BusyBox** package, which should already be enabled and already have a base
    configuration specified. If you're following along with this example, the
    correct configuration value should look like this:

    ```bash
    ${NERVES_DEFCONFIG_DIR}/busybox_defconfig
    ```

The [Buildroot user manual](http://nightly.buildroot.org/manual.html) can be
very helpful, especially if you need to add a package. The various Nerves system
repositories have examples of many common use cases, so check them out as well.


### Rebuild the System

To apply your changes, clean the output directory for the system and rebuild:

```bash
rm -rf o/<system short name>
mix ns.build
```

This ensures a fresh build with your updated configuration.

### Make Additional Modifications (Optional)

You can further customize the Nerves system by modifying other configuration files, such as:

- **System files:** Add or update scripts, binaries, or other files required by your application.

To dive deeper into kernel customization, see the [Linux Kernel Documentation](https://www.kernel.org/doc/html/latest/).

### Test the Custom Build

After rebuilding, test the custom firmware on your hardware to ensure it meets your requirements. If issues arise:

- Review the Buildroot logs in `o/<system short name>/build/`.
- Iterate on the configuration as needed.

### Version Control Your Changes
 
If your customizations are for long-term use, consider committing your changes to version control. This is especially useful for:

- Collaborating with other developers.
- Reproducing builds in the future.

Example:
Let's say that you want to version control your customized rpi3 system

```bash
cd src
cp -r nerves_system_rpi3 custom_rpi3
```

The name of the system directory is up to you, but we will call it `custom_rpi3`
in this example. It's recommended that you check your custom system into your
version control system before making changes. This makes it easier to merge in
upstream changes from the official systems later. For example, assuming you're
using GitHub:


```bash
# After creating an empty custom_rpi3 repository in your GitHub account

cd custom_rpi3
git remote rename origin upstream
git remote add origin git@github.com:YourGitHubUserName/custom_rpi3.git
git checkout -b main
git push origin main
```


Next, tweak the metadata of your Mix project by updating your `mix.exs` with the following:

* The module name of the mix project at the top of the file
* the value of `@app` to `custom_rpi3`
* the value of `@github_organization` to your GitHub user name or organization

See the [Official Mix.Project](https://hexdocs.pm/mix/Mix.Project.html) document
for the structure of this file.

```elixir
# custom_rpi3/mix.exs

# defmodule NervesSystemRpi3.MixProject do
defmodule CustomRpi3.MixProject do
  #      =^^^^^^^^^^= Rename `NervesSystemRpi3` to `CustomRpi3`
  use Mix.Project

  # @github_organization "nerves-project"
  @github_organization "YourGitHubUserOrOrganizationName"
  #                    =^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^=
  #                    Rename `"nerves-project"` here to your GitHub user or organization name

  # @app :nerves_system_rpi3
  @app :custom_rpi3
  #    =^^^^^^^^^^^= Rename `nerves_system_rpi3` here to `custom_rpi3`
end

# =^^^= The rest of this file remains the same
```

```bash
# Commit and push your changes.

git add mix.exs
git commit -m "Change project info"
git push
```

Now you can go to your `nerves_systems/config/config.exs` and add it to your systems.
