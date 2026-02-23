User: Now I want to implement mxfp8 to the inference task in qwen3. I need a highly editable implementation for further research. To be more specific, later I need the computation to be done from MSB to LSB for each element in the activation and weight, and the intermediate result in this process can be used to control computation process of other row/column or even different layers. So as the first step, I need to implement mxfp8 to the inference task in a highly editable way. Give me a plan on how to structure my code to achieve this step by step based on the current framework

GitHub Copilot: I am GitHub Copilot, powered by Gemini 3.1 Pro (Preview).

To implement a highly editable MXFP8 inference framework for Qwen3 that supports future bit-serial (MSB to LSB) computation and cross-layer control, you should avoid standard PyTorch C++/CUDA linear backends. Instead, you need a custom, pure-PyTorch (or Triton) linear layer and a context-passing mechanism. 

Since modeling_qwen3.py is auto-generated, you should make your structural changes in modular_qwen3.py (and configuration_qwen3.py), or duplicate the files into a standalone research directory to avoid Hugging Face CI overwrites.

Here is the step-by-step plan to structure your code:

### Step 1: Update the Configuration
Add MXFP8-specific arguments to `Qwen3Config` to control the quantization behavior and block sizes.

```python
# ...existing code...
    def __init__(
        self,
        # ...existing args...
        use_mxfp8: bool | None = False,
        mxfp8_block_size: int | None = 32,
        **kwargs,
    ):
        # ...existing code...
        self.use_mxfp8 = use_mxfp8
        self.mxfp8_block_size = mxfp8_block_size
        super().__init__(**kwargs)
# ...existing code...
```

### Step 2: Create a Custom MXFP8 Linear Module
Create a new class in modular_qwen3.py to replace `nn.Linear`. This class will simulate MXFP8 math and expose the bit-level computation loop.

```python
# ...existing code...
import torch.nn as nn

class MXFP8Linear(nn.Module):
    def __init__(self, in_features, out_features, bias=False, config=None):
        super().__init__()
        self.in_features = in_features
        self.out_features = out_features
        self.weight = nn.Parameter(torch.empty((out_features, in_features)))
        if bias:
            self.bias = nn.Parameter(torch.empty(out_features))
        else:
            self.register_parameter('bias', None)
        self.block_size = config.mxfp8_block_size if config else 32

    def forward(self, x, compute_context=None):
        # 1. Extract shared scales (Microscaling block logic)
        # 2. Quantize x and self.weight to simulated FP8
        
        # 3. Placeholder for your future MSB-to-LSB bit-serial computation
        # Example structure for future research:
        # out = torch.zeros(...)
        # for bit in range(7, -1, -1): # MSB to LSB
        #     bit_result = compute_bit_slice(x_fp8, weight_fp8, bit)
        #     out += bit_result
        #     if compute_context is not None:
        #         compute_context.update(layer_name, bit, bit_result)
        
        # Fallback for step 1 (standard matmul on simulated quantized weights)
        out = torch.matmul(x, self.weight.t())
        if self.bias is not None:
            out += self.bias
            
        return out
# ...existing code...
```

### Step 3: Implement a Computation Context for Cross-Layer Control
To allow intermediate results from one layer to control another, you need to pass a context dictionary through the `forward` passes.

Modify the `forward` signatures of `Qwen3Model`, `Qwen3DecoderLayer`, `Qwen3Attention`, and `Qwen3MLP` to accept a `compute_context` kwarg.

```python
# In Qwen3Model forward:
def forward(self, ..., compute_context: dict | None = None, **kwargs):
    # ...
    for decoder_layer in self.layers:
        hidden_states = decoder_layer(
            hidden_states,
            # ...
            compute_context=compute_context,
            **kwargs,
        )
```

### Step 4: Replace Standard Linear Layers
Modify `Qwen3Attention` and `Qwen3MLP` in modular_qwen3.py to conditionally use your `MXFP8Linear`.

```python
# ...existing code...
class Qwen3Attention(LlamaAttention):
    def __init__(self, config: Qwen3Config, layer_idx: int):
        # ...existing code...
        if getattr(config, "use_mxfp8", False):
            self.q_proj = MXFP8Linear(config.hidden_size, config.num_attention_heads * self.head_dim, bias=config.attention_bias, config=config)
            self.k_proj = MXFP8Linear(config.hidden_size, config.num_key_value_heads * self.head_dim, bias=config.attention_bias, config=config)
            self.v_proj = MXFP8Linear(config.hidden_size, config.num_key_value_heads * self.head_dim, bias=config.attention_bias, config=config)
            self.o_proj = MXFP8Linear(config.num_attention_heads * self.head_dim, config.hidden_size, bias=config.attention_bias, config=config)
        else:
            # Standard nn.Linear initialization
            pass
# ...existing code...
```
*(Do the exact same conditional replacement for `gate_proj`, `up_proj`, and `down_proj` in a custom `Qwen3MLP` class).*

### Step 5: Update the Forward Passes to Route the Context
Ensure that `Qwen3Attention` and `Qwen3MLP` pass the `compute_context` down to the `MXFP8Linear` layers during the forward pass.

```python
# Inside Qwen3Attention forward:
query_states = self.q_proj(hidden_states, compute_context=kwargs.get("compute_context"))
```

### Summary of Workflow
1. **Setup:** Add configs and the `MXFP8Linear` skeleton.
2. **Routing:** Plumb the `compute_context` dictionary through all `forward` methods from the top-level `Qwen3ForCausalLM` down to the linear layers.
3. **Simulation:** Implement the MXFP8 block-scaling and quantization math in pure PyTorch inside `MXFP8Linear.forward`.
4. **Bit-level logic:** Once the standard MXFP8 math is verified, replace the `torch.matmul` inside `MXFP8Linear` with your custom MSB-to-LSB loop, writing intermediate states to `compute_context`.