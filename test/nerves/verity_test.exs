# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.VerityTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  # The expected root hashes and SHA-256s in these tests were generated with
  # veritysetup 2.8.1 (cryptsetup) on Linux. Concatenating the padded data
  # file and the `.verity` file was byte-for-byte identical to veritysetup
  # output, so the "combined" SHA-256s below cover every output byte. For
  # example, for the "hashes a multi-level tree" test:
  #
  #   truncate -s $((129 * 4096)) rootfs.squashfs
  #   veritysetup format rootfs.squashfs rootfs.squashfs \
  #       --hash-offset=$((129 * 4096)) --data-blocks=129 \
  #       --data-block-size=4096 --hash-block-size=4096 \
  #       --salt=$SALT --uuid=$UUID

  @salt "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20"
  @uuid "3aaf3b00-7c5f-4f33-961c-5cb069f3e2a3"

  setup_all do
    # Throwaway signing key for the root hash signing tests
    dir = Path.join(System.tmp_dir!(), "nerves-verity-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    signing_key = Path.join(dir, "key.pem")
    signing_cert = Path.join(dir, "cert.pem")

    {_output, 0} =
      System.cmd(
        "openssl",
        [
          "req",
          "-x509",
          "-newkey",
          "rsa:2048",
          "-nodes",
          "-keyout",
          signing_key,
          "-out",
          signing_cert,
          "-subj",
          "/CN=nerves-verity-test",
          "-days",
          "2"
        ],
        stderr_to_stdout: true
      )

    %{signing_key: signing_key, signing_cert: signing_cert}
  end

  defp create_test_file(dir, size) do
    path = Path.join(dir, "rootfs.squashfs")
    count = div(size + 31, 32)
    data = for i <- 0..(count - 1), into: <<>>, do: :crypto.hash(:sha256, <<i::32>>)
    File.write!(path, binary_part(data, 0, size))
    path
  end

  # SHA-256 of the padded data file with the verity metadata placed right
  # after it. This matches the single-file layout produced by
  # `veritysetup format --hash-offset`.
  defp combined_sha256(path) do
    combined = [File.read!(path), File.read!(path <> ".verity")]
    Base.encode16(:crypto.hash(:sha256, combined), case: :lower)
  end

  test "hashes a single data block", %{tmp_dir: tmp_dir} do
    path = create_test_file(tmp_dir, 4096)

    assert {:ok, info} = Nerves.Verity.format(path, salt: @salt, uuid: @uuid)

    assert info.root_hash == "43852942edbf67069896e7054f26df81854d65e1c49f8418cd6fcf5fcebac772"
    assert info.data_blocks == 1
    assert info.hash_offset == 4096

    # Already aligned, so the data file is untouched. The verity file only
    # contains the superblock since there are no hash tree levels.
    assert File.stat!(path).size == 4096
    assert File.stat!(info.verity_path).size == 4096

    assert combined_sha256(path) ==
             "43aed0ba2d81f7893adf9f27c7eb7f9c600008bebce647ff25fb79086c4f3b3e"
  end

  test "pads files smaller than a data block", %{tmp_dir: tmp_dir} do
    path = create_test_file(tmp_dir, 1000)

    assert {:ok, info} = Nerves.Verity.format(path, salt: @salt, uuid: @uuid)

    assert info.root_hash == "a81831615de9ed657b1c06d0604ab6c0ad3a0b48249c38936666561a96a93f45"
    assert info.data_blocks == 1
    assert info.hash_offset == 4096
    assert File.stat!(path).size == 4096

    assert combined_sha256(path) ==
             "cbb0e6ef9dc9cfddeedf34e3743a0f20bc70874032af670305e934744701acea"
  end

  test "hashes a multi-level tree", %{tmp_dir: tmp_dir} do
    path = create_test_file(tmp_dir, 129 * 4096)

    assert {:ok, info} = Nerves.Verity.format(path, salt: @salt, uuid: @uuid)

    assert info.root_hash == "fa7abb8ab22db6b3d3617fa4b5da4414f17ea2d58f0771bd1931dce7b7410790"
    assert info.data_blocks == 129
    assert info.hash_offset == 129 * 4096

    # Superblock block + 1 top level block + 2 level 0 blocks
    assert File.stat!(path).size == 129 * 4096
    assert File.stat!(info.verity_path).size == 4 * 4096

    assert combined_sha256(path) ==
             "40baf1ca3471f66c18771b1bd7f52779dcd545197b111b14313e765d68a36868"
  end

  test "zero-pads unaligned files so the verity metadata lands on a 4K boundary", %{
    tmp_dir: tmp_dir
  } do
    path = create_test_file(tmp_dir, 129 * 4096 - 1234)

    assert {:ok, info} = Nerves.Verity.format(path, salt: @salt, uuid: @uuid)

    assert info.root_hash == "f54d2d7292c017cf20383f8168fd56f6966b4725c0aeb5c3ed070a6b54281a65"
    assert info.data_blocks == 129
    assert info.hash_offset == 129 * 4096
    assert File.stat!(path).size == 129 * 4096

    assert combined_sha256(path) ==
             "fec8498a6f5fa0189d339031fc0104a82606cdeebba65a9b7da5f8dd619a4c39"
  end

  test "supports sha512", %{tmp_dir: tmp_dir} do
    path = create_test_file(tmp_dir, 129 * 4096)

    assert {:ok, info} = Nerves.Verity.format(path, algorithm: :sha512, salt: @salt, uuid: @uuid)

    assert info.root_hash ==
             "d97644572730f4647a8a51b006dad83051193b665561df07cf33ee12dc3e33f551df6095c9c892d3ed5876b9a0183f92be94ef32ca6851235de86817e96590c7"

    # Superblock block + 1 top level block + 3 level 0 blocks (64 digests/block)
    assert File.stat!(info.verity_path).size == 5 * 4096

    assert combined_sha256(path) ==
             "d258148144ee360ac3f3c54fac3eae7ead12226cf360f5976a793ee3e0266e46"
  end

  test "supports an empty salt", %{tmp_dir: tmp_dir} do
    path = create_test_file(tmp_dir, 5 * 4096)

    assert {:ok, info} = Nerves.Verity.format(path, salt: "", uuid: @uuid)

    assert info.root_hash == "abdec69c821ec91037a44999063f4478d7d58f0e7d589fdcc07467ef609452d7"
    assert info.salt == ""

    assert combined_sha256(path) ==
             "e299b8f48aa551fcd25720112ffd63ef882157b3aa74d0f26de427b5ee0ceec2"
  end

  test "derives a deterministic salt and UUID by default", %{tmp_dir: tmp_dir} do
    path = create_test_file(tmp_dir, 129 * 4096)

    assert {:ok, info} = Nerves.Verity.format(path)

    assert info.root_hash == "de6cb52137bd7a9496ebc49e6212b86ba2a1bad9e47d6aa1b50e1a3c63d0d614"
    assert info.salt == "685b1eead18e9694387eb12a122e4d9b2e2042b0d39566568d54462487165dd0"
    assert info.uuid == "d6ebc1e9-9c10-4db1-8368-25ebd61ae9ad"
    assert info.algorithm == :sha256

    assert combined_sha256(path) ==
             "efff1ba9e44a568264342b3ee0e1c4010e5fac9c986e14dca50e60a2d991486c"
  end

  test "writes the verity metadata and root hash next to the file", %{tmp_dir: tmp_dir} do
    path = create_test_file(tmp_dir, 4096)

    assert {:ok, info} = Nerves.Verity.format(path, salt: @salt, uuid: @uuid)

    assert info.verity_path == path <> ".verity"
    assert info.root_hash_path == path <> ".roothash"
    assert File.read!(info.root_hash_path) == info.root_hash
    assert info.root_hash_sig_path == nil
  end

  test "signs the root hash when a key and certificate are configured", %{
    tmp_dir: tmp_dir,
    signing_key: signing_key,
    signing_cert: signing_cert
  } do
    path = create_test_file(tmp_dir, 4096)

    assert {:ok, info} =
             Nerves.Verity.format(path,
               salt: @salt,
               uuid: @uuid,
               signing_key: signing_key,
               signing_cert: signing_cert
             )

    assert info.root_hash_sig_path == path <> ".roothash.p7s"

    # The signature must be a detached PKCS#7 signature of the hex root hash
    # like the kernel's CONFIG_DM_VERITY_VERIFY_ROOTHASH_SIG expects
    {output, 0} =
      System.cmd(
        "openssl",
        [
          "smime",
          "-verify",
          "-binary",
          "-inform",
          "der",
          "-in",
          info.root_hash_sig_path,
          "-content",
          info.root_hash_path,
          "-certfile",
          signing_cert,
          "-nointern",
          "-noverify"
        ],
        stderr_to_stdout: true
      )

    assert output =~ info.root_hash
  end

  test "validates signing options", %{signing_key: signing_key, signing_cert: signing_cert} do
    assert :ok =
             Nerves.Verity.validate_options(signing_key: signing_key, signing_cert: signing_cert)

    assert {:error, ":signing_key and :signing_cert" <> _} =
             Nerves.Verity.validate_options(signing_key: signing_key)

    assert {:error, ":signing_key and :signing_cert" <> _} =
             Nerves.Verity.validate_options(signing_cert: signing_cert)

    assert {:error, ":signing_key not found" <> _} =
             Nerves.Verity.validate_options(
               signing_key: "/does/not/exist.pem",
               signing_cert: signing_cert
             )

    assert {:error, ":signing_cert not found" <> _} =
             Nerves.Verity.validate_options(
               signing_key: signing_key,
               signing_cert: "/does/not/exist.pem"
             )
  end

  test "writes a parseable superblock", %{tmp_dir: tmp_dir} do
    path = create_test_file(tmp_dir, 5 * 4096)

    assert {:ok, info} = Nerves.Verity.format(path, salt: @salt, uuid: @uuid)

    <<superblock::binary-size(512), _tree::binary>> = File.read!(info.verity_path)

    raw_uuid = Base.decode16!(String.replace(@uuid, "-", ""), case: :lower)
    raw_salt = Base.decode16!(@salt, case: :lower)

    assert <<"verity", 0, 0, 1::little-32, 1::little-32, ^raw_uuid::binary-size(16), "sha256",
             0::26-unit(8), 4096::little-32, 4096::little-32, 5::little-64, 32::little-16,
             0::6-unit(8), ^raw_salt::binary-size(32), 0::224-unit(8), 0::168-unit(8)>> =
             superblock
  end

  test "validates options" do
    assert :ok = Nerves.Verity.validate_options([])
    assert :ok = Nerves.Verity.validate_options(algorithm: :sha512, salt: @salt, uuid: @uuid)
    assert :ok = Nerves.Verity.validate_options(data_block_size: 4096, hash_block_size: 4096)

    assert {:error, ":algorithm" <> _} = Nerves.Verity.validate_options(algorithm: :md5)
    assert {:error, ":salt" <> _} = Nerves.Verity.validate_options(salt: "xyz")
    assert {:error, ":salt" <> _} = Nerves.Verity.validate_options(salt: :random)

    too_long = Base.encode16(:binary.copy(<<1>>, 257))
    assert {:error, ":salt" <> _} = Nerves.Verity.validate_options(salt: too_long)

    assert {:error, ":uuid" <> _} = Nerves.Verity.validate_options(uuid: "1234")

    assert {:error, ":data_block_size" <> _} =
             Nerves.Verity.validate_options(data_block_size: 1000)

    assert {:error, ":hash_block_size" <> _} =
             Nerves.Verity.validate_options(hash_block_size: 256)

    assert {:error, "unknown option" <> _} = Nerves.Verity.validate_options(block_size: 4096)
  end

  test "errors on missing and empty files", %{tmp_dir: tmp_dir} do
    assert {:error, "could not read" <> _} =
             Nerves.Verity.format(Path.join(tmp_dir, "missing.squashfs"))

    path = Path.join(tmp_dir, "empty.squashfs")
    File.write!(path, "")
    assert {:error, reason} = Nerves.Verity.format(path)
    assert reason =~ "is empty"
  end

  test "main/0 reads its configuration from the environment", %{
    tmp_dir: tmp_dir,
    signing_key: signing_key,
    signing_cert: signing_cert
  } do
    path = create_test_file(tmp_dir, 4096)

    env = [
      {"NERVES_VERITY_ROOTFS", path},
      {"NERVES_VERITY_ALGORITHM", "sha256"},
      {"NERVES_VERITY_SALT", @salt},
      {"NERVES_VERITY_UUID", @uuid},
      {"NERVES_VERITY_DATA_BLOCK_SIZE", "4096"},
      {"NERVES_VERITY_HASH_BLOCK_SIZE", "4096"},
      {"NERVES_VERITY_SIGNING_KEY", signing_key},
      {"NERVES_VERITY_SIGNING_CERT", signing_cert}
    ]

    Enum.each(env, fn {name, value} -> System.put_env(name, value) end)
    on_exit(fn -> Enum.each(env, fn {name, _value} -> System.delete_env(name) end) end)

    output = ExUnit.CaptureIO.capture_io(fn -> Nerves.Verity.main() end)

    assert output =~ "43852942edbf67069896e7054f26df81854d65e1c49f8418cd6fcf5fcebac772"
    assert File.exists?(path <> ".roothash.p7s")

    assert combined_sha256(path) ==
             "43aed0ba2d81f7893adf9f27c7eb7f9c600008bebce647ff25fb79086c4f3b3e"
  end
end
