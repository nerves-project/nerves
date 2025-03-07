# defmodule Nerves.Release.Rel2fw do
#   # Legacy support for calling the rel2fw.sh script to turn a release into a .fw file.
#   @default_mksquashfs_flags ["-no-xattrs", "-quiet"]

#   defp build_firmware(config, system_path, fw_out) do
#     otp_app = config[:app]
#     Nerves.Checks.check_compiler!()

#     firmware_config = Application.get_env(:nerves, :firmware)

#     mksquashfs_flags = firmware_config[:mksquashfs_flags] || @default_mksquashfs_flags
#     set_mksquashfs_flags(mksquashfs_flags)

#     rootfs_priorities =
#       Nerves.Env.package(:nerves_system_br)
#       |> rootfs_priorities()

#     rel2fw_path = Path.join(system_path, "scripts/rel2fw.sh")
#     cmd = "bash"
#     args = [rel2fw_path]

#     if firmware_config[:rootfs_additions] do
#       Mix.shell().error(
#         "The :rootfs_additions configuration option has been removed. Rename it to :rootfs_overlay."
#       )
#     end

#     build_rootfs_overlay = Path.join([Mix.Project.build_path(), "nerves", "rootfs_overlay"])
#     File.mkdir_p!(build_rootfs_overlay)

#     write_erlinit_config(build_rootfs_overlay)

#     project_rootfs_overlay = config_arg(:rootfs_overlay, firmware_config)
#     prevent_overlay_overwrites!(project_rootfs_overlay)

#     rootfs_overlays =
#       [build_rootfs_overlay | project_rootfs_overlay]
#       |> Enum.map(&["-a", &1])
#       |> List.flatten()

#     fwup_conf = config_arg(:fwup_conf, firmware_config)

#     post_processing_script = config_arg(:post_processing_script, firmware_config)

#     fw = ["-f", fw_out]
#     release_path = Path.join(Mix.Project.build_path(), "rel/#{otp_app}")
#     output = [release_path]

#     args =
#       args ++
#         fwup_conf ++
#         rootfs_overlays ++ fw ++ rootfs_priorities ++ post_processing_script ++ output

#     env = [{"MIX_BUILD_PATH", Mix.Project.build_path()} | standard_fwup_variables(config)]

#     set_provisioning(firmware_config[:provisioning])

#     config
#     |> Nerves.Env.images_path()
#     |> File.mkdir_p!()

#     shell(cmd, args, env: env)
#     |> result()
#   end
# end
