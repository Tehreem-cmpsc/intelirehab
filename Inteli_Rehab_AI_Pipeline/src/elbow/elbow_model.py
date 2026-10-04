"""The elbow rep checker's model, as the training notebook defines it
(notebooks/train_elbow_model.ipynb), so the app's Dart copy can be checked
against the real PyTorch one.

One rep = the elbow angle (degrees) resampled to 100 steps, plus log(duration in
seconds) repeated on every step. The autoencoder rebuilds the rep; the mean squared
rebuild error (in normalised units) is the score, and a score above the threshold
means "this rep looks different from a healthy one".
"""
import numpy as np
import torch
from torch import nn

N_STEPS = 100


class ConvAutoencoder(nn.Module):
    """(batch, channels, 100 steps) -> code of `latent` numbers -> (batch, channels, 100)."""

    def __init__(self, n_channels, latent=4):
        super().__init__()
        self.encoder = nn.Sequential(
            nn.Conv1d(n_channels, 32, 5, stride=2, padding=2), nn.ReLU(),   # 100 -> 50
            nn.Conv1d(32, 64, 5, stride=2, padding=2), nn.ReLU(),           # 50 -> 25
            nn.Conv1d(64, 64, 5, stride=2, padding=2), nn.ReLU(),           # 25 -> 13
            nn.Flatten(), nn.Linear(64 * 13, latent))
        self.decoder_input = nn.Linear(latent, 64 * 13)
        self.decoder = nn.Sequential(
            nn.ConvTranspose1d(64, 64, 5, stride=2, padding=2), nn.ReLU(),                      # 13 -> 25
            nn.ConvTranspose1d(64, 32, 5, stride=2, padding=2, output_padding=1), nn.ReLU(),    # 25 -> 50
            nn.ConvTranspose1d(32, n_channels, 5, stride=2, padding=2, output_padding=1))        # 50 -> 100

    def forward(self, x):
        return self.decoder(self.decoder_input(self.encoder(x)).view(-1, 64, 13))


def load_checkpoint(path):
    """The checkpoint saved by the notebook, with the model rebuilt and ready."""
    ck = torch.load(path, map_location="cpu", weights_only=False)
    model = ConvAutoencoder(n_channels=2 if ck["with_duration"] else 1, latent=ck["latent"])
    model.load_state_dict(ck["model_state"])
    model.eval()
    ck["model"] = model
    return ck


def make_input(angle, duration, with_duration):
    """angle: (reps, 100) degrees, duration: (reps,) seconds -> (reps, 100, channels)."""
    x = np.asarray(angle, dtype=np.float32)[:, :, None]
    if with_duration:
        d = np.log(np.asarray(duration, dtype=float))[:, None, None] * np.ones((1, x.shape[1], 1))
        x = np.concatenate([x, d], axis=2)
    return x.astype(np.float32)


def score_reps(ck, angle, duration):
    """Returns (score per rep, rebuilt angle curve in degrees per rep)."""
    mean, std = ck["mean"], ck["std"]
    x = ((make_input(angle, duration, ck["with_duration"]) - mean) / std).astype(np.float32)
    t = torch.from_numpy(x).permute(0, 2, 1)
    with torch.no_grad():
        out = ck["model"](t)
    score = ((out - t) ** 2).mean(dim=(1, 2)).numpy()
    rebuilt = out.permute(0, 2, 1).numpy()[:, :, 0] * std[0, 0, 0] + mean[0, 0, 0]
    return score.astype(np.float64), rebuilt.astype(np.float64)
