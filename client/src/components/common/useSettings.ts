import { useEffect, useRef } from 'react';
import { gql, useQuery } from '@apollo/client';
import { MessageType } from 'antd/lib/message';
import { message } from 'antd';

import { Settings } from '../../generated/graphql_schema';

const SETTINGS = gql`
  query Settings {
    settings {
      rpc
      bcdGuiUrl
      bcdNetwork
      contracts {
        nftFaucet
        nftFactory
      }
    }
  }
`;

export interface Data {
  settings: Settings;
}

const settings = {
  rpc: '',
  bcdGuiUrl: '',
  bcdNetwork: '',
  contracts: {
    nftFaucet: '',
    nftFactory: ''
  }
};

export default () => {
  const { data, loading, error } = useQuery<Data>(SETTINGS);
  const hideLoadingMessage = useRef<MessageType>();

  useEffect(() => {
    if (loading)
      hideLoadingMessage.current = message.loading(
        'Loading settings from the server...'
      );
    else if (error)
      message.error(`Cannot load settings from the server: ${error}`);
    else if (hideLoadingMessage.current) hideLoadingMessage.current();
  }, [loading, error]);

  return { settings: data?.settings, loading, error };
};
