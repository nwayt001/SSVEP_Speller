%SpeakText

fs = 16000;
MS = actxserver('SAPI.SpMemoryStream');
MS.Format.Type = sprintf('SAFT%dkHz16BitMono',fix(fs/1000));
SV_preRecord.AudioOutputStream = MS;
SV.Rate = -5; % speak a bit slower than normal




ttsObj = Text2Speech([]);

while 1
speak_text(ttsObj,'Addison hurry up');
end