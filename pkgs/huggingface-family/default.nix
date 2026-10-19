{ python-final, python-prev }:

rec {
  # HuggingFace family packages - ordered by dependency
  
  hf-xet = python-final.callPackage ./hf-xet { };
  
  huggingface-hub = python-final.callPackage ./huggingface-hub { 
    hf-xet = hf-xet;
  };
  
  tokenizers = python-final.callPackage ./tokenizers { 
    huggingface-hub = huggingface-hub;
  };
  
  transformers = python-final.callPackage ./transformers { 
    upstream = python-prev.transformers;
  };
  
  sentence-transformers = python-final.callPackage ./sentence-transformers { 
    transformers = transformers;
  };
}
