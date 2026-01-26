# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Fwup.Word34567 do
  # This is a vendored version of Word34567 from NervesMOTD.
  @moduledoc false

  # Compact word lookup used by fwup
  #
  # Words are stored in a tightly-packed string format where each row contains
  # 5 words with lengths 3, 4, 5, 6, and 7 (25 letters per row).

  @word34567_words ("act" <> "able" <> "about" <> "absent" <> "abandon") <>
                     ("add" <> "away" <> "aisle" <> "advice" <> "address") <>
                     ("aim" <> "best" <> "anger" <> "annual" <> "analyst") <>
                     ("all" <> "bone" <> "armor" <> "assume" <> "apology") <>
                     ("arm" <> "cake" <> "beach" <> "barrel" <> "average") <>
                     ("ask" <> "chat" <> "bless" <> "bitter" <> "bargain") <>
                     ("bar" <> "club" <> "brick" <> "bronze" <> "blanket") <>
                     ("bid" <> "corn" <> "cabin" <> "camera" <> "capital") <>
                     ("boy" <> "dash" <> "chalk" <> "casual" <> "certain") <>
                     ("can" <> "dice" <> "civil" <> "cherry" <> "coconut") <>
                     ("cat" <> "drip" <> "cloud" <> "column" <> "conduct") <>
                     ("cup" <> "east" <> "craft" <> "credit" <> "crucial") <>
                     ("day" <> "fall" <> "curve" <> "debris" <> "cushion") <>
                     ("dry" <> "fine" <> "dream" <> "depend" <> "despair") <>
                     ("egg" <> "foil" <> "earth" <> "dinner" <> "dilemma") <>
                     ("era" <> "gain" <> "entry" <> "dragon" <> "dynamic") <>
                     ("fan" <> "glad" <> "exist" <> "energy" <> "emotion") <>
                     ("few" <> "grit" <> "field" <> "estate" <> "essence") <>
                     ("fix" <> "head" <> "focus" <> "expire" <> "exhibit") <>
                     ("fog" <> "hood" <> "gauge" <> "finger" <> "fatigue") <>
                     ("fox" <> "idea" <> "glove" <> "fossil" <> "forward") <>
                     ("gap" <> "jump" <> "grunt" <> "garlic" <> "genuine") <>
                     ("hat" <> "kiwi" <> "hello" <> "guitar" <> "gravity") <>
                     ("hip" <> "lazy" <> "inner" <> "horror" <> "illness") <>
                     ("ice" <> "link" <> "labor" <> "indoor" <> "initial") <>
                     ("job" <> "loop" <> "light" <> "invest" <> "jealous") <>
                     ("key" <> "math" <> "maple" <> "laptop" <> "lecture") <>
                     ("kid" <> "mind" <> "mimic" <> "lonely" <> "lottery") <>
                     ("lab" <> "name" <> "nasty" <> "margin" <> "mention") <>
                     ("mad" <> "nose" <> "offer" <> "middle" <> "monitor") <>
                     ("mix" <> "open" <> "owner" <> "motion" <> "network") <>
                     ("net" <> "pass" <> "piano" <> "nephew" <> "observe") <>
                     ("nut" <> "plug" <> "power" <> "online" <> "ostrich") <>
                     ("oak" <> "pulp" <> "purse" <> "palace" <> "peasant") <>
                     ("oil" <> "ramp" <> "ready" <> "phrase" <> "popular") <>
                     ("one" <> "ring" <> "round" <> "praise" <> "present") <>
                     ("pen" <> "safe" <> "scrap" <> "reason" <> "program") <>
                     ("pig" <> "seed" <> "shock" <> "relief" <> "pudding") <>
                     ("raw" <> "sign" <> "skill" <> "resist" <> "raccoon") <>
                     ("rug" <> "slot" <> "snack" <> "ripple" <> "release") <>
                     ("run" <> "soon" <> "spawn" <> "salute" <> "satisfy") <>
                     ("say" <> "step" <> "spray" <> "select" <> "session") <>
                     ("shy" <> "tape" <> "still" <> "silver" <> "slender") <>
                     ("spy" <> "text" <> "super" <> "sphere" <> "stomach") <>
                     ("tag" <> "tiny" <> "table" <> "street" <> "supreme") <>
                     ("tip" <> "trip" <> "tired" <> "symbol" <> "thunder") <>
                     ("toe" <> "undo" <> "trade" <> "ticket" <> "trigger") <>
                     ("toy" <> "visa" <> "truth" <> "travel" <> "uncover") <>
                     ("two" <> "wasp" <> "vague" <> "unfold" <> "utility") <>
                     ("van" <> "wild" <> "vivid" <> "valley" <> "vibrant") <>
                     ("web" <> "yard" <> "zebra" <> "voyage" <> "weather") <>
                     "zoo"

  @doc """
  Retrieve a word by index

  ## Examples
      iex> Nerves.Fwup.Word34567.word(108)
      "garlic"

      iex> Nerves.Fwup.Word34567.word(194)
      "raccoon"
  """
  @spec word(byte()) :: String.t()
  def word(index) when index in 0..255 do
    # See fwup implementation in create_wordlist.c
    m = rem(index, 5)
    len = m + 3
    offset = div(index, 5) * 25 + div(m * (m + 5), 2)

    binary_part(@word34567_words, offset, len)
  end
end
