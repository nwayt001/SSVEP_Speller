classdef WordPredictor < handle
   
    properties
        corpus
        numWords2Predict = 9;
    end
    
    methods
        % -----------------------------------------------------------------
        % Class constructor:
        
        function self = WordPredictor(corpusDirectory)
            
            % load corpus
            if nargin < 1
                self.corpus=load('WordCorpus');
            else
                self.corpus=load(corpusDirectory);
            end
        end
        
        % -----------------------------------------------------------------
        
        function [likelyWords] = PredictWords(self,letters)
            % Predictive Speller
            likelyWords = self.corpus.WD.words;
            if(isempty(letters))
            else
                try
                    for i=1:length(letters)
                        Corpus = self.corpus.WD.(letters(i));
                        if(i==length(letters))
                            likelyWords = Corpus.words;
                        else
                        end
                    end
                catch
                    cnt=1;
                    for w=1:length(self.corpus.Words)
                        try
                            if(strcmp(self.corpus.Words{w}(1:length(letters)),letters) && cnt<10)
                                likelyWords{cnt}=self.corpus.Words{w};
                                cnt=cnt+1;
                            end
                        catch
                        end
                    end
                end
            end
        end
    end
    
end