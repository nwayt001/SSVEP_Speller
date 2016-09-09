%% Predictive Speller (requires word corpus)
function [likelyWords]=PredictWords(letters,Corpus,Words)

% Predictive Speller
if(isempty(letters))
   likelyWords = Corpus.words; 
else
    try
    for i=1:length(letters)
        Corpus = Corpus.(letters(i));
        if(i==length(letters))
            likelyWords = Corpus.words;
        else
        end
    end
    catch
        cnt=1;
        for w=1:length(Words)
            try
                if(strcmp(Words{w}(1:length(letters)),letters) && cnt<10)
                    likelyWords{cnt}=Words{w};
                    cnt=cnt+1;
                end
            catch
            end
        end
    end
end
end