classdef (Abstract) Signal_IO < handle
% Signal_IO is an abstract parent class to LSL and FT

    properties
        type % **Options: 'LSL', 'FT'
        delayAmount
        Fs
        delay
        blockSize
        waitingOnData
        channels
        num_ch
        channel_names_gNautilus = [{'FP1'},{'FP2'},{'AF3'},{'AF4'},{'F7'},{'F3'},{'FZ'},{'F4'},...
            {'F8'},{'FC5'},{'FC1'},{'FC2'},{'FC6'},{'T7'},{'C3'},{'CZ'},{'C4'},{'T8'},{'CP5'},{'CP1'},...
            {'CP2'},{'CP6'},{'P7'},{'P3'},{'PZ'},{'P4'},{'P8'},{'PO7'},{'PO3'},{'PO4'},{'PO8'},{'OZ'}];
        default_gNaut_channels_ssvep = [23:32];
        default_gNaut_channels_rsvp = [6 7 8 10 11 12 13 16 23:32];
    end
    
    methods
        %------------------------------------------------------------------
        % Class constructor:
        
        function S = Signal_IO(type,channels)
        % SIGNAL_IO is the base class constructor. The sub-classes will have
        % unique implementations.
%             delete(instrfindall);
            S.type = type;
            S.delayAmount = 0.14;
            S.waitingOnData = true;
            S.channels = channels;
            S.num_ch = length(S.channels);
        end
        
        %------------------------------------------------------------------
    end
    
    methods (Abstract)
        readBuffer(obj)
        %READBUFFER reads data from the signal buffer
        sendTrigger(obj,flag)
        %SENDTRIGGER sends a trigger pulse to amplifier to mark start or
        %end of stimulation event based on the flag
        terminate(obj)
        %TERMINATE terminates the signal buffer
    end
end