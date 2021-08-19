--Copyright (c) 2017, Alpha Data Parallel Systems Ltd.
--All rights reserved.
--
--Redistribution and use in source and binary forms, with or without
--modification, are permitted provided that the following conditions are met:
--    * Redistributions of source code must retain the above copyright
--      notice, this list of conditions and the following disclaimer.
--    * Redistributions in binary form must reproduce the above copyright
--      notice, this list of conditions and the following disclaimer in the
--      documentation and/or other materials provided with the distribution.
--    * Neither the name of the Alpha Data Parallel Systems Ltd. nor the
--      names of its contributors may be used to endorse or promote products
--      derived from this software without specific prior written permission.
--
--THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
--ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
--WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
--DISCLAIMED. IN NO EVENT SHALL Alpha Data Parallel Systems Ltd. BE LIABLE FOR ANY
--DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
--(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
--LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
--ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
--(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
--SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


--
-- FIFO buffer for narrowing stream of 256 bits to 24 bits
-- (32 words to 3 words)
-- Fully enforces flow control
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;


entity stream_narrow_64to3 is
  port (
    clk : in std_logic;
    rst : in std_logic;
    stream_in : in std_logic_vector(511 downto 0);
    stream_in_valid  : in  std_logic;
    stream_in_ready  : out std_logic;
    stream_out : out  std_logic_vector(23 downto 0);
    stream_out_valid : out std_logic;
    stream_out_ready : in std_logic);
end entity;

architecture rtl of stream_narrow_64to3 is

  signal stream_buffer : std_Logic_vector(1535 downto 0) := (others => '0');
  signal buffer_used : std_logic_vector(191 downto 0) := (others => '0');
  signal wr_addr : unsigned(1 downto 0) := (others => '0');
  signal rd_addr : unsigned(6 downto 0) := (others => '0'); 

  signal stream_in_ready_i : std_logic := '0';

  type stream_buffer_type is array (0 to 63) of std_logic_vector(23 downto 0);
  
  
  
begin

  stream_in_ready <= stream_in_ready_i;
  
  process(clk)
    variable sb_var : stream_buffer_type;
    variable bu_var : std_logic_vector(63 downto 0);
  begin
    if rising_edge(clk) then
      if wr_addr = 0 then
        if stream_in_ready_i = '1' and stream_in_valid = '1' then
          stream_in_ready_i <= '0';
          stream_buffer(511 downto 0) <= stream_in;
          buffer_used(63 downto 0) <= (others => '1');
          wr_addr <= wr_addr+1;
        else
          stream_in_ready_i <= not buffer_used(63);
        end if;
      elsif wr_addr = 1 then
        if stream_in_ready_i = '1' and stream_in_valid = '1' then
          stream_in_ready_i <= '0';
          stream_buffer(1023 downto 512) <= stream_in;
          buffer_used(127 downto 64) <= (others => '1');
          wr_addr <= wr_addr+1;
        else
          stream_in_ready_i <= not buffer_used(63);
        end if;
      elsif wr_addr = 2 then
        if stream_in_ready_i = '1' and stream_in_valid = '1' then
          stream_in_ready_i <= '0';
          stream_buffer(1535 downto 1024) <= stream_in;
          buffer_used(191 downto 128) <= (others => '1');
          wr_addr <= (others => '0');
        else
          stream_in_ready_i <= not buffer_used(95);
        end if;
      end if;

      for i in 0 to 63 loop
        sb_var(i) := stream_buffer(24*i+23 downto 24*i);
        bu_var(i) := buffer_used(3*i);
      end loop;
      stream_out <= sb_var(to_integer(rd_addr));
      stream_out_valid <= bu_var(to_integer(rd_addr));
      if bu_var(to_integer(rd_addr)) = '1' and stream_out_ready = '1' then
        rd_addr <= rd_addr+1;
        for i in 0 to 63 loop
          if to_integer(unsigned(rd_addr)) = i then
            buffer_used(3*i) <= '0';
            buffer_used(3*i+1) <= '0';
            buffer_used(3*i+2) <= '0';
          end if;
        end loop;
      end if;
      
      if rst = '1' then
        buffer_used <= (others => '0');
        wr_addr <= (others => '0');
        rd_addr <= (others => '0');
        stream_in_ready_i <= '0';
      end if;
      
    end if;
  end process;    
 
  
end architecture;
