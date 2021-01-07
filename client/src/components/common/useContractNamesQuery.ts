import useAsync from '../../utils/useAsync';
import { contractNames } from '../../resolvers/contractNames';

const settings = {
  rpc: 'https://delphinet-tezos.giganode.io',
  bcdApiUrl: 'https://api.better-call.dev',
  bcdGuiUrl: 'https://better-call.dev',
  bcdNetwork: 'delphinet',
  contracts: {
    nftFaucet: 'KT1CV1zsMnrnVHHZLKGdZ16bpSKhXfbJ8G8T',
    nftFactory: 'KT1HDdJAXVxi3scXydzhLZio2KipbyPJSru5'
  }
};

export const useContractNamesQuery = (
  contractOwnerAddress?: string,
  nftOwnerAddress?: string
) => {
  return useAsync(
    () =>
      contractNames(
        contractOwnerAddress,
        nftOwnerAddress,
        settings.contracts.nftFactory,
        settings.contracts.nftFaucet,
        settings.bcdApiUrl,
        settings.bcdNetwork
      ),
    []
  );
};
