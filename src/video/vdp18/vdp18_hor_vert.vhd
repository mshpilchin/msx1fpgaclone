-------------------------------------------------------------------------------
--
-- Synthesizable model of TI's TMS9918A, TMS9928A, TMS9929A.
--
-- $Id: vdp18_hor_vert.vhd,v 1.11 2006/06/18 10:47:01 arnim Exp $
--
-- Horizontal / Vertical Timing Generator
--
-------------------------------------------------------------------------------
--
-- Copyright (c) 2006, Arnim Laeuger (arnim.laeuger@gmx.net)
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- Please report bugs to the author, but before you do so, please
-- make sure that this is not a derivative work and that
-- you have the latest version of this file.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.vdp18_pack.opmode_t;
use work.vdp18_pack.hv_t;

entity vdp18_hor_vert is

  generic (
	 is_cvbs_g		: boolean := false
  );
  port (
    clock_i       : in  std_logic;
    clk_en_5m37_i : in  boolean;
    reset_i       : in  boolean;
    opmode_i      : in  opmode_t;
	 ntsc_pal_i		: in  std_logic;
    num_pix_o     : out hv_t;
    num_line_o    : out hv_t;
    vert_inc_o    : out boolean;
    hsync_n_o     : out std_logic;
    vsync_n_o     : out std_logic;
    blank_o       : out boolean
  );

end vdp18_hor_vert;


use work.vdp18_pack.all;

architecture rtl of vdp18_hor_vert is

  signal last_line_s  : hv_t;
  signal first_line_s : hv_t;

  signal first_pix_s  : hv_t;
  signal last_pix_s   : hv_t;

  signal cnt_hor_q    : hv_t;
  signal cnt_vert_q   : hv_t;

  signal vert_inc_s   : boolean;

  signal hblank_q,
         vblank_q     : boolean;

begin

  -----------------------------------------------------------------------------
  -- Prepare comparison signals for NTSC and PAL.
  --
	first_line_s <= hv_first_line_ntsc_c when ntsc_pal_i = '0' else hv_first_line_pal_c;
	last_line_s  <= hv_last_line_ntsc_c  when ntsc_pal_i = '0' else hv_last_line_pal_c;
  --
  -----------------------------------------------------------------------------


  -----------------------------------------------------------------------------
  -- Process opmode_mux
  --
  -- Purpose:
  --   Generates the horizontal counter limits based on the current operating
  --   mode.
  --
  opmode_mux: process (opmode_i)
  begin
    if opmode_i = OPMODE_TEXTM then
      first_pix_s <= hv_first_pix_text_c;
      last_pix_s  <= hv_last_pix_text_c;
    else
      first_pix_s <= hv_first_pix_graph_c;
      last_pix_s  <= hv_last_pix_graph_c;
    end if;
  end process opmode_mux;
  --
  -----------------------------------------------------------------------------


	-----------------------------------------------------------------------------
	-- Process counters
	--
	-- Purpose:
	--   Implements the horizontal and vertical counters.
	--
	counters: process (clock_i, reset_i, first_line_s)
		variable ch1_v	: integer;
		variable ch2_v	: integer;
		variable ch3_v	: integer;
		variable ch4_v	: integer;
	begin
		if is_cvbs_g then
			ch1_v := -64;
			ch2_v := -38;
			ch3_v := -72;
			ch4_v := -14;
		else
			ch1_v := -56;
			ch2_v := -30;
			ch3_v := -69;
			ch4_v := -11;
		end if;

		if reset_i then
			cnt_hor_q  <= hv_first_pix_text_c;
			cnt_vert_q <= first_line_s;
			hsync_n_o  <= '1';
			vsync_n_o  <= '1';
			hblank_q   <= false;
			vblank_q   <= false;

		elsif clock_i'event and clock_i = '1' then
			if clk_en_5m37_i then
				-- The horizontal counter ---------------------------------------------
				if cnt_hor_q = last_pix_s then
					cnt_hor_q  <= first_pix_s;
				else
					cnt_hor_q <= cnt_hor_q + 1;
				end if;

				-- The vertical counter -----------------------------------------------
				if cnt_vert_q = last_line_s then
					cnt_vert_q <= first_line_s;
				elsif vert_inc_s then
					-- increment when horizontal counter is at trigger position
					cnt_vert_q <= cnt_vert_q + 1;
				end if;

				-- Horizontal sync ----------------------------------------------------
				if    cnt_hor_q = ch1_v then		-- -64		-44		-56
					hsync_n_o <= '0';
				elsif cnt_hor_q = ch2_v then		-- -38		-18		-30
					hsync_n_o <= '1';
				end if;
				if    cnt_hor_q = ch3_v then		-- -72		-62		-69
					hblank_q  <= true;
				elsif cnt_hor_q = ch4_v then		-- -14		-4			-11
					hblank_q  <= false;
				end if;

				-- Vertical sync ------------------------------------------------------
				if ntsc_pal_i = '1' then
					if    cnt_vert_q = 244 then
						vsync_n_o <= '0';
					elsif cnt_vert_q = 247 then
						vsync_n_o <= '1';
					end if;

					if    cnt_vert_q = 242 then
						vblank_q  <= true;
					elsif cnt_vert_q = first_line_s + 13 then
						vblank_q  <= false;
					end if;
				else
					if    cnt_vert_q = 218 then
						vsync_n_o <= '0';
					elsif cnt_vert_q = 221 then
						vsync_n_o <= '1';
					end if;

					if    cnt_vert_q = 215 then
						vblank_q  <= true;
					elsif cnt_vert_q = first_line_s + 13 then
						vblank_q  <= false;
					end if;
				end if;
			end if;
		end if;
	end process counters;
	--
	-----------------------------------------------------------------------------


  -- comparator for vertical line increment
  vert_inc_s <= clk_en_5m37_i and cnt_hor_q = hv_vertical_inc_c;


  -----------------------------------------------------------------------------
  -- Output mapping
  -----------------------------------------------------------------------------
  num_pix_o  <= cnt_hor_q;
  num_line_o <= cnt_vert_q;
  vert_inc_o <= vert_inc_s;
  blank_o    <= hblank_q or vblank_q;

end rtl;