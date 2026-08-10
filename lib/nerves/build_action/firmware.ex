# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildAction.Firmware do
  @moduledoc """
  Release step that creates the firmware image.

  Runs `fwup` to combine the rootfs squashfs image with the system's
  firmware configuration to produce a `.fw` file suitable for writing
  to an SD card or uploading to a device.

  Configuration:

  * `:fw_version` - Version number for firmware file
  * `:fw_product` - Product name
  * `:fw_description` - Product description
  * `:fw_author` - Firmware author
  * `:fw_vcs_identifier` - A git commit hash or other vcs identifier
  * `:fw_misc` - An arbitrary string for the firmware's misc field
  * `:images_path` - Where images are stored
  * `:firmware_path` - Path to the output `.fw` file
  * `:rootfs_path` - Path to the input rootfs file

  """

  use Nerves.BuildAction

  alias Nerves.MixUtils

  @spec default_config() :: %{
          images_path: String.t(),
          firmware_path: String.t(),
          rootfs_path: String.t(),
          fw_version: term(),
          fw_product: String.t(),
          fw_description: term(),
          fw_author: term(),
          fw_vcs_identifier: String.t(),
          fw_misc: String.t()
        }
  def default_config() do
    project_config = Mix.Project.config()

    # Don't fill in by default since we can't assume any one version
    # control system even though it's tempting to assume git. Nerves 1.x
    # did not fill this in.
    vcs_id = ""

    images_path = Path.join([Mix.Project.build_path(), "nerves", "images"])

    # TODO: think about pushing more config to local opts so that its possible
    # to create multiple firmware images. Not sure how useful this is at the
    # moment, but might be interesting for OTA vs complete images or some other
    # .fw alternatives.
    %{
      images_path: images_path,
      firmware_path: Path.join(images_path, "#{project_config[:app]}.fw"),
      rootfs_path: Path.join(images_path, "#{project_config[:app]}.rootfs"),
      fw_version: project_config[:version],
      fw_product: to_string(project_config[:name] || project_config[:app]),
      fw_description: project_config[:description] || "",
      fw_author: project_config[:author] || "",
      fw_vcs_identifier: vcs_id,
      fw_misc: ""
    }
  end

  @spec validate!(Nerves.BuildPlan.t()) :: :ok
  def validate!(%Nerves.BuildPlan{} = build_plan) do
    required_config = [
      :images_path,
      :firmware_path,
      :rootfs_path,
      :fwup_conf,
      :fwup_provisioning_conf,
      :source_date_epoch,
      :fw_version,
      :fw_product,
      :fw_description,
      :fw_author,
      :fw_vcs_identifier,
      :fw_misc
    ]

    missing_keys = Enum.reject(required_config, &Map.has_key?(build_plan.config, &1))

    if missing_keys != [] do
      raise Nerves.InvalidPlan,
        message: "BuildPlan is missing required configuration for #{inspect(missing_keys)}"
    end

    :ok
  end

  @doc """
  Run the firmware step.

  Creates the `.fw` file using fwup and the combined.rootfs image from
  a previous step.

  Options:

  """
  @impl Nerves.BuildAction
  def image_creation(%Nerves.BuildPlan{} = build_plan, opts) do
    opts = Map.merge(build_plan.config, Map.new(opts))

    validate!(build_plan)
    create_fw!(build_plan, opts)

    MixUtils.success("Firmware built successfully!")
    MixUtils.info("  #{opts[:firmware_path]}")

    :ok
  end

  defp create_fw!(build_plan, opts) do
    fwup = find_fwup!(build_plan)
    fwup_conf = opts[:fwup_conf]
    fw_out = opts[:firmware_path]

    File.mkdir_p!(Path.dirname(fw_out))

    fwup_env =
      [
        {"ROOTFS", opts[:rootfs_path]},
        {"MIX_BUILD_PATH", Mix.Project.build_path()}
        | fwup_variables(opts)
      ] ++
        maybe_env("NERVES_PROVISIONING", opts[:fwup_provisioning_conf]) ++
        maybe_env("SOURCE_DATE_EPOCH", opts[:source_data_epoch])

    MixUtils.info("  Creating #{Path.basename(fw_out)}...")

    case System.cmd(fwup, ["-c", "-f", fwup_conf, "-o", fw_out],
           env: fwup_env,
           stderr_to_stdout: true
         ) do
      {_, 0} -> :ok
      {output, code} -> Mix.raise("fwup failed (exit #{code}):\n#{output}")
    end
  end

  defp fwup_variables(opts) do
    [
      {"NERVES_FW_VERSION", opts[:fw_version]},
      {"NERVES_FW_PRODUCT", opts[:fw_product]},
      {"NERVES_FW_DESCRIPTION", opts[:fw_description]},
      {"NERVES_FW_AUTHOR", opts[:fw_author]},
      {"NERVES_FW_VCS_IDENTIFIER", opts[:fw_vcs_identifier]},
      {"NERVES_FW_MISC", opts[:fw_misc]}
    ]
  end

  defp maybe_env(key, value) when is_binary(value), do: [{key, value}]
  defp maybe_env(_key, _value), do: []

  defp find_fwup!(build_plan) do
    # Explicitly look through the Nerves-provided paths to avoid breaking due to
    # build_plan.env diverging from the OS environment. This shouldn't happen
    # unless code modifies the OS environment outside of the BuildPlan, and they
    # shouldn't be doing that.
    case :os.find_executable(~c"fwup", String.to_charlist(build_plan.env["PATH"])) do
      false -> Mix.raise("fwup not found. Install it: https://github.com/fhunleth/fwup")
      fwup -> List.to_string(fwup)
    end
  end
end
