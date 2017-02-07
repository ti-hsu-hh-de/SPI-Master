--------------------------------------------------------------------------------
-- Entity: spiMaster
--------------------------------------------------------------------------------
--! @file spiMaster.vhd
--! @brief contains entity and architecture for spi4prhs
--! @author René Kirschen and Marcel Eckert
--! @email eckert@hsu-hh.de
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

--! @brief
--! spi master module for variable data length

--! @detailed This module implements a spi master device
--! The input clock has to be twice the wanted spi-clock frequency; either by applying it directly
--! via iSysClk or via iSPIclkEn as an iSysClk aligned clock-enable
entity spiMaster is
generic (
		Gen_DataLength : integer := 8
);
port(
		iSysClk       : in std_logic;                      --! system clock
        iSPIclkEn     : in std_logic;					   --! spi clock enable signal (related to iSysClk)
        iReset        : in std_logic;                      --! reset signal

        odMOSI        : out std_logic;                     --! master out slave in
        idMISO        : in  std_logic;                      --! master in slave out
        oSClk         : out std_logic;                     --! spi clock to slaves

        icCPOL		  : in  std_logic;					   --! clock polarity
        icCPHA		  : in  std_logic;					   --! clock phase

        odByteRead    : out std_logic_vector (Gen_DataLength - 1 downto 0); --! read data
        idByteWrite   : in 	std_logic_vector (Gen_DataLength - 1 downto 0);  --! data to send

        icStart       : in 	std_logic;                      --! start a spi transfers - handshake signal
        ocReadyToSend : out std_logic                       --! spi host is ready for a transfer - handshake signal
     );
end spiMaster;

architecture Behavioral of spiMaster is
type StateType is (WAITING,DATAphaseA,DATAphaseB);
signal SPIClk : std_logic;
signal state : StateType;

signal rcDataPos : integer;


-- Automat
begin
process(iSysClk)
begin
if rising_edge(iSysClk) then
    if iReset = '1' then
            ocReadyToSend <='1';
            SPIClk <= '0';
            odMOSI <= '0';
            state <= WAITING;
            rcDataPos <= 0;
    else
    	-- It is necessary to immediately apply a modified CPOL to SPIclk,
    	-- because the following problem might occur:
    	-- CPOL is set to another value in one cycle of iSysClk; in the next cycle
    	-- Chip select might be asserted; if we wait for iSPIclkEn to occur before changing SPIclk in
    	-- accordance to CPOL it might be too late and an attached slave might "see" a SPI clock edge
    	if state = waiting then
    		SPIClk <= icCPOL;
    	end if;

    	if iSPIclkEn = '1' then

	        case state is
	            when WAITING =>   --Initial-Zustand
	                if (icStart= '1') then
	                    odMOSI <= idByteWrite(Gen_DataLength - 1);
	                    state <= DATAPhaseA;
	                    ocReadyToSend <= '0';
	                    rcDataPos <= Gen_DataLength - 1;
	                end if;
	            when DATAPhaseA =>
	                state <= DATAPhaseB;
	                if (icCPHA = '0') then
	                	odByteRead(rcDataPos) <= idMISO;
	                else
	                	odMOSI <= idByteWrite(rcDataPos);
	                end if;
	                SPIClk <= not SPIClk;
	            when DATAPhaseB =>
	            	if (icCPHA = '0') then
										if (rcDataPos /= 0) then
	                		odMOSI <= idByteWrite(rcDataPos-1);
										end if;
	               	else
	               		odByteRead(rcDataPos) <= idMISO;
	               	end if;
	                state <= DATAPhaseA;
	                SPIClk <= not SPIClk;
	                if rcDataPos = 0 then
	                	ocReadyToSend <= '1';
		                state <= WAITING;
	                else
	                	rcDataPos <= rcDataPos - 1;
	               	end if;
	        end case;
	    end if;
	end if;
end if;
end process;
oSClk <= SPIClk;
end Behavioral;
