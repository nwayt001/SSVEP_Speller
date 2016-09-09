classdef FT < Signal_IO
% FT is the signal aqcuisition module that accesses EEG data from the
% fieldtrip buffer from bci2000. It can work in two modes: 1) g.USB 
% with udp port triggers or 2) with g.Nautilus with parallel port triggers.
    properties
        ft_buffer
        hdr
        udpSocket
        prevSample
        debugMode
        parallel_mode = true;
        parallel_obj
        parallel_status
        parallel_address
        startEvent
        endEvent
    end
    methods
        %------------------------------------------------------------------
        % Class constructor: initializes the signal source buffer. It takes
        % as input the trial length (in seconds), and a 1 or 0 to indicate 
        % if delay should be used, respectively.
        
        function ft = FT(trialLength,includeDelay,channels,debugMode, parallel_mode)
            ft@Signal_IO('FT',channels);
            ft.debugMode = debugMode;
            
            if(~debugMode)
                % initialize ft buffer and get sampling frequency
                ft.ft_buffer = 'buffer://localhost:1972';
                ft.prevSample = 0;
                ft.hdr = ft_read_header(ft.ft_buffer,'cache',true);
                ft.Fs = ft.hdr.Fs;
                ft.blockSize = trialLength*ft.Fs;
                ft.delay=floor(ft.Fs*ft.delayAmount*includeDelay);
                ft.parallel_mode = parallel_mode;
                
                if(ft.parallel_mode)
                    % initialize paralle port comms
                    ft.parallel_obj = io64();
                    ft.parallel_status = io64(ft.parallel_obj);
                    ft.parallel_address = hex2dec('378');
                    io64(ft.parallel_obj,ft.parallel_address,0);
                    ft.startEvent = 1;
                    ft.endEvent = 0;
                else 
                    % initialize arduino comms
                    ft.udpSocket = udp('192.168.208.135',1236);
                    fopen(ft.udpSocket);
                    fwrite(ft.udpSocket,'y');
                    ft.startEvent = 0;
                    ft.endEvent = 1;
                end
            end
        end
        %------------------------------------------------------------------
        
        function data=readBuffer(obj)
        %READBUFFER reads data from the signal buffer and extracts one
        %trial
            if(~obj.debugMode)
                obj.waitingOnData=true;
                while(obj.waitingOnData)
                    obj.hdr = ft_read_header(obj.ft_buffer,'cache',true);
                    newsamples = (obj.hdr.nSamples*obj.hdr.nTrials);
                    begsample = obj.prevSample+1;
                    data = ft_read_data(obj.ft_buffer, 'header', obj.hdr, 'begsample', begsample, 'endsample', newsamples, 'chanindx', 1:obj.hdr.nChans);
                    data = data';
                    startIdx = find(data(2:end,end)~=obj.endEvent & data(1:end-1,end)==obj.endEvent, 1);
                    
                    if(~isempty(startIdx))
                        if(size(data,1) >= (startIdx+obj.blockSize+obj.delay-1))
                            data = data(startIdx+obj.delay:startIdx+obj.delay+obj.blockSize-1,obj.channels);
                            obj.prevSample = obj.prevSample+startIdx+obj.delay+obj.blockSize;
                            obj.waitingOnData = false;
                        end
                    end
                end
            else
                data=[];
            end
        end
        
        function sendTrigger(obj,flag)
        %SENDTRIGGER sends a trigger pulse to mark start or end of trial
        %base on the flag
            if(~obj.debugMode)
                switch flag
                    case 'start'
                        if(obj.parallel_mode)
                            io64(obj.parallel_obj,obj.parallel_address,1);
                        else
                            fwrite(obj.udpSocket,'n');
                        end
                    case 'stop'
                        if(obj.parallel_mode)
                            io64(obj.parallel_obj,obj.parallel_address,0);
                        else
                            fwrite(obj.udpSocket,'y');
                        end
                end
            end
        end
        
        function terminate(obj)
        %TERMINATE terminates the signal buffer
            if(~obj.debugMode)
                if(obj.parallel_mode)
                    clear obj.parallel_obj
                else
                    fclose(obj.udpSocket);
                end
            end
        end
    end
    
end
